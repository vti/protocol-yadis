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
    isa     => 'Bool',
    is      => 'rw',
    default => 0
);

has _resource => (
    isa     => 'Str',
    is      => 'rw'
);

has error => (
    isa => 'Str',
    is  => 'rw'
);

# debugging
has debug => (
    isa     => 'Int',
    is      => 'rw',
    default => sub { $ENV{PROTOCOL_YADIS_DEBUG} || 0 }
);

use Protocol::Yadis::Document;

sub _headers { {'Accept' => 'application/xrds+xml'} }

sub discover {
    my $self = shift;
    my ($url, $cb) = @_;

    my $method = $self->head_first ? 'HEAD' : 'GET';

    $self->_resource('');

    if ($method eq 'GET') {
        return $self->_initial_req($url, sub { $cb->(@_) });
    }
    else {
        $self->_initial_head_req(
            $url => sub {
                my ($self, $retry) = @_;

                return $self->_initial_req($url, sub { $cb->(@_) }) if $retry;

                return $cb->($self) unless $self->_resource;

                return $self->_second_req(
                    $self->_resource => sub { $cb->(@_); });
            }
        );
    }
}

sub _initial_req {
    my $self = shift;
    my ($url, $cb) = @_;

    $self->_initial_get_req(
        $url => sub {
            my ($self, $document) = @_;

            return $cb->($self, $document) if $document;

            return $cb->($self) unless $self->_resource;

            return $self->_second_req(
                $self->_resource => sub { $cb->(@_); });
        }
    );
}

sub _parse_document {
    my $self = shift;
    my ($headers, $body) = @_;

    if ($headers->{'Content-Type'}
        =~ m/^(?:application\/xrds\+xml|text\/xml);?/)
    {
        my $document = Protocol::Yadis::Document->parse($body);

        return $document if $document;
    }

    return;
}

sub _initial_head_req {
    my $self = shift;
    my ($url, $cb) = @_;

    warn 'HEAD request' if $self->debug;

    $self->http_req_cb->(
        $url, 'HEAD',
        $self->_headers, undef => sub {
            my ($url, $status, $headers, $body) = @_;

            return $cb->($self) unless $status && $status == 200;

            if (my $location = $headers->{'X-XRDS-Location'}) {
                warn 'Found X-XRDS-Location' if $self->debug;

                $self->_resource($location);

                return $cb->($self);
            }

            $cb->($self, 1);
        }
    );
}

sub _initial_get_req {
    my $self = shift;
    my ($url, $cb) = @_;

    warn 'GET request' if $self->debug;

    $self->http_req_cb->(
        $url, 'GET',
        $self->_headers, undef => sub {
            my ($url, $status, $headers, $body) = @_;

            warn 'after user callback' if $self->debug;

            warn "status=$status";
            return $cb->($self) unless $status && $status == 200;

            warn 'status is ok' if $self->debug;

            if (my $location = $headers->{'X-XRDS-Location'}) {
                warn 'Found X-XRDS-Location' if $self->debug;

                $self->_resource($location);

                if ($body) {
                    warn 'Found body' if $self->debug;

                    my $document = $self->_parse_document($headers, $body);

                    return $cb->($self, $document) if $document;
                }

                warn 'no yadis was found' if $self->debug;

                return $cb->($self);
            }

            warn 'No X-XRDS-Location header was found' if $self->debug;

            if ($body) {
                my $document = $self->_parse_document($headers, $body);
                return $cb->($self, $document) if $document;

                warn 'Found HMTL' if $self->debug;
                my ($head) = ($body =~ m/<\s*head\s*>(.*?)<\/\s*head\s*>/is);
                return $cb->($self) unless $head;

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

                $self->_resource($location) if $location;
            }

            warn 'no body was found' if $self->debug;

            return $cb->($self);
        }
    );
}

sub _second_req {
    my $self = shift;
    my ($url, $cb) = @_;

    warn 'Second GET request' if $self->debug;

    $self->http_req_cb->(
        $url, 'GET',
        $self->_headers, undef => sub {
            my ($url, $status, $headers, $body) = @_;

            return $cb->($self) unless $status && $status == 200;

            return $cb->($self) unless $body;

            my $document = $self->_parse_document($headers, $body);
            return $cb->($self, $document) if $document;

            rerturn $cb->($self);
        }
    );
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
                }
                else {
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
