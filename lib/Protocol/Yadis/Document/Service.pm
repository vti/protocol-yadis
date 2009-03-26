package Protocol::Yadis::Document::Service;
use Mouse;

use overload '""' => sub { shift->to_string }, fallback => 1;

has attrs => (
    isa     => 'ArrayRef[Str]',
    is      => 'rw',
    default => sub { [] }
);

has _elements => (
    isa     => 'ArrayRef[Protocol::Yadis::Document::Service::Element]',
    is      => 'rw',
    default => sub { [] }
);

sub Type { shift->element('Type') }
sub URI  { shift->element('URI') }

sub element {
    my $self = shift;
    my $name = shift;
    return unless $name;

    if (my @elements = grep { $_->name eq $name } @{$self->elements}) {
        return [@elements];
    }
}

sub elements {
    my $self = shift;

    if (@_) {
        $self->_elements([]);

        foreach my $element (@{$_[0]}) {
            push @{$self->_elements}, $element;
        }
    } else {
        my @priority = grep { $_->attr('priority') } @{$self->_elements};
        my @other    = grep { !$_->attr('priority') } @{$self->_elements};

        my @sorted =
          sort { $a->attr('priority') cmp $b->attr('priority') } @priority;
        push @sorted, @other;

        return [sort {$a->name cmp $b->name} @sorted];
    }
}

sub attr {
    my $self  = shift;
    my $name  = shift;
    return unless $name;

    my $attrs = $self->attrs;

    my $i = 0;
    for (; $i < @$attrs; $i += 2) {
        last if $attrs->[$i] eq $name;
    }

    if (@_) {
        my $value = shift;
        if ($i >= @$attrs) {
            push @$attrs, ($name => $value) if $value;
        }
        else {
            $attrs->[$i + 1] = $value;
        }
        return $self;
    }

    return if $i >= @$attrs;

    return $attrs->[$i + 1];
}

sub to_string {
    my $self = shift;

    my $attrs = '';
    for (my $i = 0; $i < @{$self->attrs}; $i += 2) {
        next unless $self->attrs->[$i + 1];
        $attrs .= ' ';
        $attrs .= $self->attrs->[$i] . '="' . $self->attrs->[$i + 1] . '"';
    }

    my $elements = '';
    foreach my $element (@{$self->elements}) {
        $elements .= "\n";
        $elements .= " $element";
    }
    $elements .= "\n" if $elements;

    return "<Service$attrs>$elements</Service>";
}

1;
