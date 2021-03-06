package Teto::Server::Buffer;
use Any::Moose;
use POSIX qw(ceil);

use constant META_INTERVAL => 1 * 1024;

use constant {
    BUFFER_SIZE_MAX => 32 * 1024, # 32kb
    BUFFER_SIZE_MIN =>       512,
};

has buffer => (
    traits  => [ 'String' ],
    is      => 'rw',
    isa     => 'Str',
    default => q(),
    handles => {
        append => 'append',
        length => 'length',
    },
);

has meta_interval => (
    is  => 'rw',
    isa => 'Int',
    default => sub { META_INTERVAL },
);

has meta_data => (
    is  => 'rw',
    isa => 'HashRef',
    default => sub { +{} },
);

has do_interleave => (
    is  => 'rw',
    isa => 'Bool',
    default => sub { 1 },
);

__PACKAGE__->meta->make_immutable;

no Any::Moose;

sub is_empty {
    shift->length < BUFFER_SIZE_MIN;
}

sub is_full {
    shift->length > BUFFER_SIZE_MAX;
}

sub write {
    my $self = shift;
    my $data = join '', @_;

    if ($self->do_interleave) {
        my $title = $self->meta_data->{title} || '';
        utf8::encode $title if utf8::is_utf8 $title;
        my $meta = qq(StreamTitle='$title';);
        my $len = ceil(length($meta) / 16);
        my $metadata_section = chr($len) . $meta . ("\x00" x (16 * $len - length $meta));

        while (length($data) >= $self->meta_interval) {
            $self->append(substr $data, 0, $self->meta_interval, '');
            $self->append($metadata_section);
            $self->{meta_interval} = META_INTERVAL;
        }

        $self->{meta_interval} -= length $data;
    }

    $self->append($data);
}

sub read {
    my ($self, $len) = @_;
    return substr $self->{buffer}, 0, $len, '';
}

1;
