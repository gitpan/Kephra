package Kephra::App::MenuBar;
$VERSION = 0.07;

use strict;

sub _ref {
	if (ref $_[0] eq 'Wx::MenuBar'){ $Kephra::app{menubar} = $_[0] }
	else                           { $Kephra::app{menubar} }
}

sub create {
	my $menubar_def = Kephra::Config::File::load_from_config_node_data
		( $Kephra::config{app}{menubar} );
	unless ($menubar_def) {
		require Kephra::Config::Embedded;
		$menubar_def = Kephra::Config::Embedded::mainmenu();
	}
	my $menubar    = Wx::MenuBar->new();
	my ($pos, $menu_name);
	for my $menu_def ( @$menubar_def ){
		for my $menu_id (keys %$menu_def){
			# removing the menu command if there is one
			$pos = index $menu_id, ' ';
			if ($pos > -1){
				if ('menu' eq substr $menu_id, 0, $pos ){
					$menu_name = substr ($menu_id, $pos+1);
				# ignoring menu structure when command other that menu or blank
				} else { next }
			} else { 
				$menu_name = $menu_id;
			}
			$menubar->Append(
				Kephra::App::Menu::create_static( $menu_name, $menu_def->{$menu_id}),
				$Kephra::localisation{app}{menu}{$menu_name}
			);
		}
	}
	Kephra::App::Window::_ref()->SetMenuBar($menubar);
	_ref($menubar);
}

1;
