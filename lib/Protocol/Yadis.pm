package Protocol::Yadis;

use strict;
use warnings;

require Carp;

our $VERSION = '0.501';

use constant DEBUG => $ENV{PROTOCOL_YADIS_DEBUG} || 0;

sub new {
    my $class = shift;
    my %param = @_;

    my $self = {@_};
    bless $self, $class;

    Carp::croak('http_req_cb is required') unless $self->{http_req_cb};

    $self->{_headers} = {'Accept' => 'application/xrds+xml'};

    return $self;
}

sub http_req_cb { shift->{http_req_cb} }
sub head_first  { shift->{head_first} }
sub error       { defined $_[1] ? $_[0]->{error} = $_[1] : $_[0]->{error} }

use Protocol::Yadis::Document;

sub discover {
    my $self = shift;
    my ($url, $cb) = @_;

    my $method = $self->head_first ? 'HEAD' : 'GET';

    $self->{_resource} = '';
    $self->error('');

    if ($method eq 'GET') {
        return $self->_initial_req($url, sub { $cb->(@_) });
    }
    else {
        $self->_initial_head_req(
            $url => sub {
                my ($self, $retry) = @_;

                return $self->_initial_req($url, sub { $cb->(@_) }) if $retry;

                return $cb->($self) unless $self->{_resource};

                return $self->_second_req(
                    $self->{_resource} => sub { $cb->(@_); });
            }
        );
    }
}

sub _parse_document {
    my $self = shift;
    my ($headers, $body) = @_;

    my $content_type = $headers->{'Content-Type'};

    if (   $content_type
        && $content_type =~ m/^(?:application\/xrds\+xml|text\/xml);?/)
    {
        my $document = Protocol::Yadis::Document->parse($body);

        return $document if $document;
    }

    return;
}

sub _initial_req {
    my $self = shift;
    my ($url, $cb) = @_;

    $self->_initial_get_req(
        $url => sub {
            my ($self, $document) = @_;

            return $cb->($self, $document) if $document;

            return $cb->($self) unless $self->{_resource};

            return $self->_second_req($self->{_resource} => sub { $cb->(@_); });
        }
    );
}

sub _initial_head_req {
    my $self = shift;
    my ($url, $cb) = @_;

    warn 'HEAD request' if DEBUG;

    $self->http_req_cb->(
        $url, 'HEAD',
        $self->{_headers},
        undef => sub {
            my ($url, $status, $headers, $body) = @_;

            return $cb->($self) unless $status && $status == 200;

            if (my $location = $headers->{'X-XRDS-Location'}) {
                warn 'Found X-XRDS-Location' if DEBUG;

                $self->{_resource} = $location;

                return $cb->($self);
            }

            $cb->($self, 1);
        }
    );
}

sub _initial_get_req {
    my $self = shift;
    my ($url, $cb) = @_;

    warn 'GET request' if DEBUG;

    $self->http_req_cb->(
        $url, 'GET',
        $self->{_headers},
        undef => sub {
            my ($url, $status, $headers, $body) = @_;

            warn 'after user callback' if DEBUG;

            return $cb->($self) unless $status && $status == 200;

            warn 'status is ok' if DEBUG;

            if (my $location = $headers->{'X-XRDS-Location'}) {
                warn 'Found X-XRDS-Location' if DEBUG;

                $self->{_resource} = $location;

                if ($body) {
                    warn 'Found body' if DEBUG;

                    my $document = $self->_parse_document($headers, $body);

                    return $cb->($self, $document) if $document;
                }

                warn 'no yadis was found' if DEBUG;

                return $cb->($self);
            }

            warn 'No X-XRDS-Location header was found' if DEBUG;

            if ($body) {
                my $document = $self->_parse_document($headers, $body);
                return $cb->($self, $document) if $document;

                warn 'Found HMTL' if DEBUG;
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

                $self->{_resource} = $location if $location;
            }

            warn 'no body was found' if DEBUG;

            return $cb->($self);
        }
    );
}

sub _second_req {
    my $self = shift;
    my ($url, $cb) = @_;

    warn 'Second GET request' if DEBUG;

    $self->http_req_cb->(
        $url, 'GET',
        $self->{_headers},
        undef => sub {
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
__END__

=head1 NAME

Protocol::Yadis - Asynchronous Yadis implementation

=head1 SYNOPSIS

    my $y = Protocol::Yadis->new(
        http_req_cb => sub {
            my ($url, $method, $headers, $body, $cb) = @_;

            ...

            $cb->($url, $status, $headers, $body);
        }
    );

    $y->discover(
        $url => sub {
            my ($self, $document) = @_;

            if ($document) {
                my $services = $document->services;

                ...
            }
            else {
                die 'error';
            }
        }
    );

=head1 DESCRIPTION

This is an asynchronous lightweight but full Yadis implementation.

=head1 ATTRIBUTES

=head2 C<http_req_cb>

    my $y = Protocol::Yadis->new(
        http_req_cb => sub {
            my ($url, $method, $headers, $body, $cb) = @_;

            ...

            $cb->($url, $status, $headers, $body);
        }
    );

This is a required callback that is used to download documents from the network.
Don't forget, that redirects can occur. This callback must handle them properly.
That is why after finishing downloading, callback must be called with the final
$url.

Arguments that are passed to the request callback

=over

=item * B<url> url where to start Yadis discovery

=item * B<method> request method

=item * B<headers> request headers

=item * B<body> request body

=item * B<cb> callback that must be called after download was completed

=back

Arguments that must be passed to the response callback

=over

=item * B<url> url from where the document was downloaded

=item * B<status> response status

=item * B<headers> response headers

=item * B<body> response body

=back

=head2 C<head_first>

Do HEAD request first. Disabled by default.

=head1 METHODS

=head2 C<new>

Creates a new L<Protocol::Yadis> instance.

=head2 C<discover>

    $y->discover(
        $url => sub {
            my ($self, $document) = @_;

            if ($document) {
                my $services = $document->services;

                ...
            }
            else {
                die 'error';
            }
        }
    );

Discover Yadis document at the url provided. Callback is called when discovery
was finished. If no document was passed there was an error during discovery.

If a Yadis document was discovered you get L<Protocol::Yadis::Document> instance
containing all the services.

=head2 C<error>

Returns last error.

=head1 AUTHOR

Viacheslav Tykhanovskyi, C<vti@cpan.org>.

=head1 COPYRIGHT

Copyright (C) 2009, Viacheslav Tykhanovskyi.

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl 5.10.

=cut
