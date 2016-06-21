package WLE::4X::Objects::Element;

use strict;
use warnings;


use WLE::4X::Methods::Simple;

#############################################################################
# constructor args
#
# 'server'		- required
#

sub new {
    my $class		= shift;
    my %args		= @_;

    my $self = bless {}, $class;

    $args{'type'} = 'element';

    return $self->_init( %args );
}

#############################################################################

sub _init {
    my $self		= shift;
    my %args		= @_;

    $self->{'SERVER'} = undef;

    $self->{'TAG'} = '';
    $self->{'SOURCE'} = '';

    $self->{'LONG_NAME'} = '';

    $self->{'OWNER_ID'} = '';

    $self->{'REQUIRED_OPTION'} = '';

    $self->{'PROVIDES'} = [];

    $self->{'PARENT_TAG'} = '';
    $self->{'CHILD_TAGS'} = [];

    unless ( defined( $args{'type'} ) ) {
        return undef;
    }

    $self->{'TYPE'} = $args{'type'};

    unless ( defined( $args{'server'} ) ) {
        return undef;
    }

    $self->{'SERVER'} = $args{'server'};

    if ( defined( $args{'tag'} ) ) {
        $self->{'TAG'} = $args{'tag'};
    }

    return $self;
}

#############################################################################

sub server {
    my $self        = shift;

    return $self->{'SERVER'};
}

#############################################################################

sub tag {
    my $self        = shift;

    return $self->{'TAG'};
}

#############################################################################

sub source_tag {
    my $self        = shift;

    return $self->{'SOURCE_TAG'};
}

#############################################################################

sub long_name {
    my $self        = shift;

    return $self->{'LONG_NAME'};
}

#############################################################################

sub owner_id {
    my $self        = shift;

    return $self->{'OWNER_ID'};
}

#############################################################################

sub set_owner_id {
    my $self        = shift;
    my $value       = shift;

    $self->{'OWNER_ID'} = $value;
}
#############################################################################

sub required_option {
    my $self        = shift;

    return $self->{'REQUIRED_OPTION'};
}

#############################################################################

sub provides {
    my $self        = shift;

    return $self->{'PROVIDES'};
}

#############################################################################

sub does_provide {
    my $self        = shift;
    my $value       = shift;

    if ( $value eq '' ) {
        return 1;
    }

    return matches_any( $value, @{ $self->provides() } );
}

#############################################################################

sub type {
    my $self        = shift;

    return $self->{'TYPE'};
}

#############################################################################

sub parent_tag {
    my $self        = shift;

    return $self->{'PARENT_TAG'};
}

#############################################################################

sub set_parent_tag {
    my $self        = shift;
    my $value       = shift;

    unless ( $value = $self->tag() ) {
        $self->{'PARENT_TAG'} = $value;
    }

    return;
}

#############################################################################

sub child_tags {
    my $self        = shift;

    return @{ $self->{'CHILD_TAGS'} };
}

#############################################################################

sub add_child {
    my $self        = shift;
    my $tag         = shift;
    my $position    = shift; $position = -1                 unless defined( $position );

    if ( $tag eq $self->tag() ) {
        return;
    }

    if ( matches_any( $tag, $self->child_tags() ) ) {
        return;
    }

    if ( $position >= scalar( @{ $self->{'CHILD_TAGS'} } ) ) {
        $position = -1;
    }

    if ( $position == 0 ) {
        unshift( @{ $self->['CHILD_TAGS'] }, $tag );
        return;
    }

    if ( $position == -1 ) {
        push( @{ $self->['CHILD_TAGS'] }, $tag );
        return;
    }

    splice( @{ $self->{'CHILD_TAGS'} }, $position, 0, $tag );

    return;
}

#############################################################################

sub remove_child {
    my $self        = shift;
    my $tag         = shift;

    my @children = @{ $self->{'CHILD_TAGS'} };
    $self->{'CHILD_TAGS'} = [];

    foreach my $child ( @children ) {
        unless ( $child eq $tag ) {
            push( @{ $self->{'CHILD_TAGS'} }, $child );
        }
    }

    return;
}

#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( defined( $r_hash ) ) {
        return 0;
    }

    if ( $self->{'TAG'} eq '' ) {

        unless ( defined( $r_hash->{'TAG'} ) ) {
            return 0;
        }

        $self->{'TAG'} = $r_hash->{'TAG'};
    }

    unless ( defined( $r_hash->{'SOURCE_TAG'} ) ) {
        return 0;
    }

    $self->{'SOURCE_TAG'} = $r_hash->{'SOURCE_TAG'};

    if ( defined( $r_hash->{'LONG_NAME'} ) ) {
        $self->{'LONG_NAME'} = $r_hash->{'LONG_NAME'};
    }

    if ( defined( $r_hash->{'OWNER_ID'} ) ) {
        $self->set_owner_id( $r_hash->{'OWNER_ID'} );
    }

    if ( defined( $r_hash->{'REQUIRED_OPTION'} ) ) {
        $self->{'REQUIRED_OPTION'} = $r_hash->{'REQUIRED_OPTION'};
    }

    my $provides = $r_hash->{'PROVIDES'};

    if ( ref( $provides ) eq 'SCALAR') {
        unless ( $provides eq '' ) {
            push( @{ $self->{'PROVIDES'} }, $provides );
        }
    }
    elsif ( ref( $provides ) eq 'ARRAY' ) {
        push( @{ $self->{'PROVIDES'} }, @{ $provides } );
    }


    return 1;
}

#############################################################################

sub to_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( defined( $r_hash ) ) {
        return 0;
    }

    $r_hash->{'TAG'} = $self->tag();
    $r_hash->{'SOURCE_TAG'} = $self->source_tag();
    $r_hash->{'LONG_NAME'} = $self->long_name();
    $r_hash->{'OWNER_ID'} = $self->owner_id();
    $r_hash->{'REQUIRED_OPTION'} = $self->required_option();

    $r_hash->{'PROVIDES'} = @{ $self->provides() };

    return 1;
}

#############################################################################
#############################################################################
1
