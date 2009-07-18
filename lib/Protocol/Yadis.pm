package Protocol::Yadis;
use Any::Moose;

# callbacks
has http_req_cb => (
    required => 1,
    isa      => 'CodeRef',
    is       => 'rw',
);

# attributes
has head_first => (
    isa     => 'Int',
    is      => 'rw',
    default => 0,
    clearer => 'clear_head_first'
);

has document => (
    isa => 'Protocol::Yadis::Document',
    is  => 'rw',
    clearer => 'clear_document'
);

has resource => (
    isa => 'Str',
    is  => 'rw',
    clearer => 'clear_resource'
);

has error => (
    isa     => 'Str',
    is      => 'rw',
    clearer => 'clear_error'
);

# debugging
has debug => (
    isa     => 'Int',
    is      => 'rw',
    default => sub { $ENV{PROTOCOL_YADIS_DEBUG} || 0 }
);

use Protocol::Yadis::Document;

sub clear {
    my $self = shift;

    $self->clear_head_first;
    $self->clear_document;
    $self->clear_resource;
    $self->clear_error;
}

sub discover {
    my $self = shift;
    my $url  = shift;
    my $cb   = shift;

    my $headers = {'Accept' => 'application/xrds+xml'};

    my $method = $self->head_first ? 'HEAD' : 'GET';

    $self->http_req_cb->(
        $self, $url, $method, $headers, '' =>
          sub {
            my ($self, $status, $headers, $body) = @_;

            $self->_http_res_on($url, $status, $headers, $body);

            return $cb->($self, 'error') if $self->error;
            return $cb->($self, 'ok')    if $self->document;

            $self->http_req_cb->(
                $self, $self->resource, 'GET', $headers, '' => sub {
                    my ($self, $status, $headers, $body) = @_;

                    $self->_http_res_on($url, $status, $headers, $body);

                    return $cb->($self, 'ok') if $self->document;
                    return $cb->($self, 'error');
                }
            );
        }
    );

    return;
}


sub _http_res_on {
    my ($self, $url, $status, $headers, $body) = @_;

    unless ($status == 200) {
        warn 'Status != 200' if $self->debug;
        $self->error("Wrong status response: $status");
        return;
    }

    if (my $location = $headers->{'X-XRDS-Location'}) {
        warn 'Found X-XRDS-Location' if $self->debug;

        # Some nasty providers set X-XRDS-Location even if they give you Yadis
        # document. Thanks God they put there the same url and we can catch it.
        return $self->resource($location) unless $location eq $url;
    }

    if ($body) {
        warn 'Found body' if $self->debug;
        $headers->{'Content-Type'} ||= '';
        if ($headers->{'Content-Type'} =~ m/^application\/xrds\+xml;?/) {
            warn 'Found Yadis Document' if $self->debug;
            my $document = Protocol::Yadis::Document->new;
            return $self->error("Can't parse Yadis Document") unless $document->parse($body);

            $self->document($document);
        }
        else {
            warn 'Found HMTL' if $self->debug;
            my ($head) = ($body =~ m/<\s*head\s*>(.*?)<\/\s*head\s*>/is);
            return $self->error('No <head> was found') unless $head;

            my $location;
            my $tags = _html_tag(\$head);
            foreach my $tag (@$tags) {
                next unless $tag->{name} eq 'meta';

                my $attrs = $tag->{attrs};
                next
                  unless %$attrs
                      && $attrs->{'http-equiv'}
                      && $attrs->{'http-equiv'} =~ m/^X-XRDS-Location$/i;

                last if ($location = $attrs->{content});
            }

            return $self->error("Can't find location") unless $location;

            $self->resource($location);
        }
    } else {
        warn 'No body was found' if $self->debug;
        $self->error('No body was found');
    }
}

# based on HTML::TagParser
sub _html_tag {
    my $txtref = shift;    # reference
    my $flat   = [];

    while (
        $$txtref =~ s{
        ^(?:[^<]*) < (?:
            ( / )? ( [^/!<>\s"'=]+ )
            ( (?:"[^"]*"|'[^']*'|[^"'<>])+ )?
        |   
            (!-- .*? -- | ![^\-] .*? )
        ) \/?> ([^<]*)
    }{}sxg
      )
    {
        my $attrs;
        if ($3) {
            my $attr = $3;
            my $name;
            my $value;
            while ($attr =~ s/^([^=]+)=//s) {
                $name = lc $1;
                $name =~ s/^\s*//s;
                $name =~ s/\s*$//s;
                $attr =~ s/^\s*//s;
                if ($attr =~ m/^('|")/s) {
                    my $quote = $1;
                    $attr =~ s/^$quote(.*?)$quote//s;
                    $value = $1;
                } else {
                    $attr =~ s/^(.*?)\s*//s;
                    $value = $1;
                }
                $attrs->{$name} = $value;
            }
        }

        next if defined $4;
        my $hash = {
            name    => lc $2,
            content => $5,
            attrs   => $attrs
        };
        push(@$flat, $hash);
    }

    return $flat;
}

1;
