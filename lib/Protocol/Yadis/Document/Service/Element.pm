package Protocol::Yadis::Document::Service::Element;
use Mouse;

use overload '""' => sub { shift->to_string }, fallback => 1;

has name => (
    isa     => 'Str',
    is      => 'rw',
    default => ''
);

has content => (
    isa     => 'Str',
    is      => 'rw',
    default => ''
);

has attrs => (
    isa     => 'ArrayRef[Str]',
    is      => 'rw',
    default => sub { [] }
);

sub attr {
    my $self  = shift;
    my $name  = shift;
    my $value = shift;

    my $attrs = $self->attrs;

    my $i = 0;
    for (; $i < @$attrs; $i += 2) {
        last if $attrs->[$i] eq $name;
    }

    if ($value) {
        if ($i >= @$attrs) {
            push @$attrs, ($name => $value);
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

    my $name = $self->name;
    return unless $name;

    my $attrs = '';
    for (my $i = 0; $i < @{$self->attrs}; $i += 2) {
        $attrs .= ' ';
        $attrs .= $self->attrs->[$i] . '="' . $self->attrs->[$i + 1] . '"';
    }
    my $content = $self->content;

    return "<$name$attrs>$content</$name>";
}

1;
