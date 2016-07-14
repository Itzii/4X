package WLE::Objects::Stack;

use strict;
use warnings;

use WLE::Methods::Simple qw( shuffle_in_place matches_any );

#############################################################################

sub new {
    my $class		= shift;
    my %args		= @_;

    my $self = bless {}, $class;

    return $self->_init( %args );
}

#############################################################################

sub _init {
    my $self		= shift;
    my %args		= @_;

    $self->{'FLAG_EXCLUSIVE'} = 0;
    $self->{'ITEMS'} = [];

    if ( defined( $args{'flag_exclusive'} ) ) {
        $self->{'FLAG_EXCLUSIVE'} = 1;
    }

    return $self;
}

#############################################################################

sub clear {
    my $self        = shift;

    $self->{'ITEMS'} = [];

    return;
}

#############################################################################

sub items {
    my $self        = shift;

    return @{ $self->{'ITEMS'} };
}

#############################################################################

sub count {
    my $self        = shift;

    return scalar( @{ $self->{'ITEMS'} } );
}

#############################################################################

sub fill {
    my $self        = shift;
    my @items       = @_;

    $self->clear();
    $self->add_items( @items );

    return;
}

#############################################################################

sub add_items {
    my $self        = shift;
    my @items       = @_;

    unless ( $self->{'FLAG_EXCLUSIVE'} ) {
        push( @{ $self->{'ITEMS'} }, @items );
        return;
    }

    foreach my $item ( @items ) {
        unless ( matches_any( $item, @{ $self->{'ITEMS'} } ) ) {
            push( @{ $self->{'ITEMS'} }, $item );
        }
    }

    return;
}

#############################################################################

sub draw_item {
    my $self        = shift;

    if ( scalar( @{ $self->{'ITEMS'} } ) < 1 ) {
        return undef;
    }

    return shift( @{ $self->{'ITEMS'} } );
}

#############################################################################

sub remove_item {
    my $self            = shift;
    my $removed_item    = shift;

    my @holder = ();
    my $flag_found_it = 0;

    foreach my $item ( $self->items() ) {
        if ( $self->{'FLAG_EXCLUSIVE'} ) {
            unless ( $item eq $removed_item ) {
                push( @holder, $item );
            }
        }
        else {
            if ( $flag_found_it == 0 && $item eq $removed_item ) {
                $flag_found_it = 1;
            }
            else {
                push( @holder, $item );
            }
        }
    }

    $self->{'ITEMS'} = \@holder;

    return;
}

#############################################################################

sub select_random_item {
    my $self        = shift;

    my @items = $self->items();

    if ( scalar( @items ) < 1 ) {
        return undef;
    }

    shuffle_in_place( \@items );

    return $items[ 0 ];
}

#############################################################################

sub contains {
    my $self        = shift;
    my $value       = shift;

    return ( matches_any( $value, $self->items() ) );
}

#############################################################################

sub shuffle {
    my $self        = shift;

    shuffle_in_place( $self->{'ITEMS'} );

    return;
}

#############################################################################
#############################################################################
1
