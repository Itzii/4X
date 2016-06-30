package WLE::4X::Objects::Race;

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

    $args{'type'} = 'race';

    return $self->_init( %args );
}

#############################################################################

sub _init {
    my $self		= shift;
    my %args		= @_;

    unless ( $self->WLE::4X::Objects::Element::_init( %args ) ) {
        return undef;
    }

    $self->{'EXCLUDE_RACE'} = '';
    $self->{'HOME'} = '';

    $self->{'COLONY_COUNT'} = 3;
    $self->{'EXCHANGE'} = 2;

    $self->{'ACTIONS'} = {
        'EXPLORE' => 1,
        'INFLUENCE_INF' => 2,
        'INFLUENCE_COLONY' => 2,
        'RESEARCH' => 1,
        'UPGRADE' => 2,
        'BUILD' => 2,
        'MOVE' => 3,
    };

    $self->{'RESOURCES'} = {
        'MONEY' => 2,
        'SCIENCE' => 3,
        'MINERALS' => 3,
    };

    $self->{'TRACKS'} = {
        'INFLUENCE' => [ -30, -25, -21, -17, -13, -10, -7, -5, -3, -2, -1, 0, 0 ],
        'MONEY' => [ 28, 24, 21, 18, 15, 12, 10, 8, 6, 4, 3, 2 ],
        'SCIENCE' => [ 28, 24, 21, 18, 15, 12, 10, 8, 6, 4, 3, 2 ],
        'MINERALS' => [ 28, 24, 21, 18, 15, 12, 10, 8, 6, 4, 3, 2 ],
    };

    $self->{'TECH'} = {
        'MILITARY' => {
            'COST' => [ 0, -1, -2, -3, -4, -6, -8, 0 ],
            'VP' => [ 0, 0, 0, 0, 1, 2, 3, 5 ],
            'POSSESS' => [],
        },
        'GRID' => {
            'COST' => [ 0, -1, -2, -3, -4, -6, -8, 0 ],
            'VP' => [ 0, 0, 0, 0, 1, 2, 3, 5 ],
            'POSSESS' => [],
        },
        'NANO' => {
            'COST' => [ 0, -1, -2, -3, -4, -6, -8, 0 ],
            'VP' => [ 0, 0, 0, 0, 1, 2, 3, 5 ],
            'POSSESS' => [],
        },
    };

    $self->{'STARTING_SHIPS'} = [ 'class_interceptor' ],

    $self->{'VP_SLOTS'} = {
        'AMBASSADOR' => 1,
        'BATTLE' => 0,
        'ANY' => 4,
    };

    $self->{'COST_ORBITAL'} = 5;

    $self->{'COST_MONUMENT'} = 10;

    $self->{'SHIP_TEMPLATES'} = [];

    if ( defined( $args{'hash'} ) ) {
        if ( $self->from_hash( $args{'hash'} ) ) {
            return $self;
        }
        return undef;
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

sub count {
    my $self        = shift;

    return $self->{'COUNT'};
}

#############################################################################

sub provides {
    my $self        = shift;

    return @{ $self->{'PROVIDES'} };
}

#############################################################################

sub does_provide {
    my $self        = shift;
    my $value       = shift;

    if ( $value eq '' ) {
        return 1;
    }

    return matches_any( $value, $self->provides() );
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

    unless( $self->WLE::4X::Objects::Element::from_hash( $r_hash ) ) {
        return 0;
    }

    unless ( defined( $r_hash->{'HOME'} ) ) {
        return 0;
    }

    $self->{'HOME'} = $r_hash->{'HOME'};

    if ( defined( $r_hash->{'EXCLUDE_RACE'} ) ) {
        $self->{'EXCLUDE_RACE'} = $r_hash->{'EXCLUDE_RACE'};
    }

    if ( defined( $r_hash->{'COLONY_COUNT'} ) ) {
        $self->{'COLONY_COUNT'} = $r_hash->{'COLONY_COUNT'};
    }

    if ( defined( $r_hash->{'EXCHANGE'} ) ) {
        $self->{'EXCHANGE'} = $r_hash->{'EXCHANGE'};
    }

    if ( defined( $r_hash->{'ACTIONS'} ) ) {
        foreach my $action_tag ( 'EXPLORE', 'INFLUENCE_INF', 'INFLUENCE_COLONY', 'RESEARCH', 'UPGRADE', 'BUILD', 'MOVE' ) {
            if ( looks_like_number( $r_hash->{'ACTIONS'}->{ $action_tag } ) ) {
                $self->{'ACTIONS'}->{ $action_tag } = $r_hash->{'ACTIONS'}->{ $action_tag };
            }
        }
    }

    if ( defined( $r_hash->{'RESOURCES'} ) ) {
        foreach my $resource_tag ( 'MONEY', 'SCIENCE', 'MINERALS' ) {
            if ( looks_like_number( $r_hash->{'ACTIONS'}->{ $resource_tag } ) ) {
                $self->{'RESOURCES'}->{ $resource_tag } = $r_hash->{'RESOURCES'}->{ $resource_tag };
            }
        }
    }

    if ( defined( $r_hash->{'TRACKS'} ) ) {
        foreach my $track_tag ( 'INFLUENCE', 'MONEY', 'SCIENCE', 'MINERALS' ) {
            if ( ref( $r_hash->{'TRACKS'}->{ $track_tag } ) eq 'ARRAY' ) {
                my @track = @{ $r_hash->{'TRACKS'}->{ $track_tag } };
                $self->{'TRACKS'}->{ $track_tag } = \@track;
            }
        }
    }

    if ( defined( $r_hash->{'TECH'} ) ) {
        foreach my $tech_tag ( 'MILITARY', 'GRID', 'NANO' ) {
            foreach my $section_tag ( 'COST', 'VP', 'POSSESS' ) {
                if ( ref( $r_hash->{'TECH'}->{ $tech_tag }->{ $section_tag } ) eq 'ARRAY' ) {
                    my @values = @{ $r_hash->{'TECH'}->{ $tech_tag }->{ $section_tag } };
                    $self->{'TECH'}->{ $tech_tag }->{ $section_tag } = \@values;
                }
            }
        }
    }

    if ( defined( $r_hash->{'STARTING_SHIPS'} ) ) {
        my @ships = @{ $r_hash->{'STARTING_SHIPS'} };
        $r_hash->{'STARTING_SHIPS'} = \@ships;
    }

    if ( defined( $r_hash->{'VP_SLOTS'} ) ) {
        foreach my $section_tag ( 'AMBASSADOR', 'BATTLE', 'ANY' ) {
            if ( looks_like_number( $r_hash->{'VP_SLOTS'}->{ $section_tag } ) ) {
                $self->{'VP_SLOTS'}->{ $section_tag } = $r_hash->{'VP_SLOTS'}->{ $section_tag };
            }
        }
    }

    foreach my $tag ( 'COST_ORBITAL', 'COST_MONUMENT' ) {
        if ( looks_like_number( $r_hash->{ $tag } ) ) {
            $self->{ $tag } = $r_hash->{ $tag };
        }
    }

    my @templates = ();
    my $template_index = 1;

    if ( defined( $r_hash->{'SHIP_TEMPLATES'} ) ) {
        if ( ref( $r_hash->{'SHIP_TEMPLATES'} ) eq 'ARRAY' ) {

            foreach my $template_section ( @{ $r_hash->{'SHIP_TEMPLATES'} } ) {

                if ( ref( $template_section ) eq 'HASHREF' ) {
                    if ( defined( $template_section->{'COST'} ) ) {
                        my $tag = $self->long_name();
                        $tag =~ s{ \W }{_}xsi;
                        $tag = 'shiptemplate_' . $tag . '_' . $template_index;

                        my $original_template = $self->server()->templates()->{ $template_section->{'TAG'} };
                        if ( defined( $original_template ) ) {
                            my $template = $original_template->copy_of( $tag );

                            if ( defined( $template ) ) {



                                $template->set_long_name( $template_section->{'LONG_NAME'} );
                                $template->set_cost( $template_section->{'COST'} );

                                push( @templates, $template->tag() );
                                $self->server()->templates()->{ $template->tag() } = $template;

                                push( @{ $self->{'SHIP_TEMPLATES'} }, $tag );
                            }
                        }
                    }
                }
                else {

                    push( @{ $self->{'SHIP_TEMPLATES'} }, $template_section );
                }
            }
        }
    }

    $self->{'SHIP_TEMPLATES'} = \@templates;

    return 1;
}

#############################################################################

sub to_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( $self->WLE::4X::Objects::Element::to_hash( $r_hash ) ) {
        return 0;
    }

    foreach my $tag ( 'HOME', 'EXCLUDE_RACE', 'COLONY_COUNT', 'EXCHANGE', 'COST_ORBITAL', 'COST_MONUMENT' ) {
        $r_hash->{ $tag } = $self->{ $tag };
    }

    $r_hash->{'ACTIONS'} = {};
    foreach my $action_tag ( 'EXPLORE', 'INFLUENCE_INF', 'INFLUENCE_COLONY', 'RESEARCH', 'UPGRADE', 'BUILD', 'MOVE' ) {
        $r_hash->{'ACTION'}->{ $action_tag } = $self->{'ACTIONS'}->{ $action_tag };
    }

    $r_hash->{'RESOURCES'} = {};
    foreach my $resource_tag ( 'MONEY', 'SCIENCE', 'MINERALS' ) {
        $r_hash->{'RESOURCES'}->{ $resource_tag } = $self->{'RESOURCES'}->{ $resource_tag };
    }

    $r_hash->{'TRACKS'} = {};
    foreach my $track_tag ( 'INFLUENCE', 'MONEY', 'SCIENCE', 'MINERALS' ) {
        my @values = @{ $self->{'TRACKS'}->{ $track_tag } };
        $r_hash->{'TRACKS'}->{ $track_tag } = \@values;
    }

    $r_hash->{'TECH'} = {};
    foreach my $tech_tag ( 'MILITARY', 'GRID', 'NANO' ) {
        $r_hash->{'TECH'}->{ $tech_tag } = {};
        foreach my $section_tag ( 'COST', 'VP', 'POSSESS' ) {
            my @values = @{ $self->{'TECH'}->{ $tech_tag }->{ $section_tag } };
            $r_hash->{'TECH'}->{ $tech_tag }->{ $section_tag } = \@values;
        }
    }

    my @ships = @{ $self->{'STARTING_SHIPS'} };
    $r_hash->{'STARTING_SHIPS'} = \@ships;

    $r_hash->{'VP_SLOTS'} = {};
    foreach my $section_tag ( 'AMBASSADOR', 'BATTLE', 'ANY' ) {
        $r_hash->{'VP_SLOTS'}->{ $section_tag } = $self->{'VP_SLOTS'}->{ $section_tag };
    }

    my @templates = ();
    foreach my $template_tag ( @{ $self->{'SHIP_TEMPLATES'} } ) {
        my $template = $self->server()->templates()->{ $template_tag };

        if ( defined( $template ) ) {
            my $template_hash = {};
            if ( $template->to_hash( $template_hash ) ) {
                push( @templates, $template_hash );
            }
        }
    }

    $r_hash->{'SHIP_TEMPLATES'} = \@templates;

    return 1;
}

#############################################################################
#############################################################################
1
