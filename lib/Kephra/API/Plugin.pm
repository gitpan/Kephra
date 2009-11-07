package Kephra::API::Plugin;
use strict;
use warnings;

our $VERSION = '0.00';

=head1 NAME

Kephra::API::Extension - API for extentions (plugins)

=head1 DESCRIPTION

Not yet specced but extention will be installed and uninstalled
(not just copied) loaded when Kephra starts. They can extend the editor
in any way since they can mount functions to any event and provide new
menus, menu items even whole modules.

=cut


sub install {}
sub uninstall {}

sub is_loaded {}
sub all_loaded {}
sub load_all {
	#require Kephra::Extention::Demo;
}
sub load {}
sub unload {}

1;