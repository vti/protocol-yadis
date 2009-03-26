package Protocol::Yadis::Document;
use Mouse;

use overload '""' => sub { shift->to_string }, fallback => 1;

use Protocol::Yadis::Document::Service;
use Protocol::Yadis::Document::Service::Element;

use XML::LibXML;

has _services => (
    isa     => 'ArrayRef[Protocol::Yadis::Document::Service]',
    is      => 'rw',
    default => sub { [] }
);

sub services {
    my $self = shift;

    if (@_) {
        $self->_services([]);

        return $self;
    } else {
        my @priority = grep { $_->attr('priority') } @{$self->_services};
        my @other    = grep { !$_->attr('priority') } @{$self->_services};

        my @sorted =
          sort { $a->attr('priority') cmp $b->attr('priority') } @priority;
        push @sorted, @other;

        return [@sorted];
    }

    return $self->_services;
}

sub parse {
    my $self = shift;
    my $document = shift;

    return unless $document;

    my $parser = XML::LibXML->new;
    my $doc;
    eval {$doc = $parser->parse_string($document); };
    return if $@;

    use Data::Dumper;

    # Get XRDS
    my $xrds = shift @{$doc->getElementsByTagName('xrds:XRDS')};

    # Get /last/ XRD
    my @xrd = $xrds->getElementsByTagName('XRD');
    my $xrd = $xrd[-1];

    my $services = [];
    my @services = $xrd->getElementsByTagName('Service');
    foreach my $service (@services) {
        my $s =
          Protocol::Yadis::Document::Service->new(attrs =>
              [map { $_->getName => $_->getValue } $service->attributes]);

        my $elements = [];
        my @nodes = $service->childNodes;
        foreach my $node (@nodes) {
            next unless $node->isa('XML::LibXML::Element');

            my @attrs = $node->attributes;
            my $content = $node->textContent;
            $content =~ s/^\s*//s;
            $content =~ s/\s*$//s;

            my $element = Protocol::Yadis::Document::Service::Element->new(
                name    => $node->getName,
                content => $content,
                attrs   => [map { $_->getName => $_->getValue } @attrs]
            );

            push @$elements, $element;
        }

        $s->elements($elements);

        next unless $s->Type;

        push @{$self->_services}, $s;
    }

    return $self;
}

sub to_string {
    my $self = shift;

    my $string = '';

    $string .= '<?xml version="1.0" encoding="UTF-8"?>' . "\n";

    $string .= ' <xrds:XRDS xmlns:xrds="xri://" xmlns="xri://*(*2.0)"' . "\n";
    $string .= '     xmlns:openid="http://openid.net/xmlns/1.0">' . "\n";

    $string .= " <XRD>\n";

    foreach my $service (@{$self->services}) {
        $string .= $service->to_string;
    }

    $string .= " </XRD>\n";
    $string .= "</xrds:XRDS>\n";

    return $string;
}

1;
