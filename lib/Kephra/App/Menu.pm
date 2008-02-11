package Kephra::App::Menu;
$VERSION = '0.12';

=pod
Module Kephra::App::Menu - Menu handling for the main app
=cut

use strict;
use Wx qw (wxITEM_NORMAL wxITEM_CHECK wxITEM_RADIO wxBITMAP_TYPE_XPM);
use Wx::Event qw (EVT_MENU EVT_MENU_OPEN EVT_MENU_HIGHLIGHT EVT_SET_FOCUS);

sub _set{$Kephra::app{menu}{$_[0]}{ref} = $_[1] if ref $_[1] eq 'Wx::Menu'}
sub _get{$Kephra::app{menu}{$_[0]}{ref} }

# ready menu for display
sub ready {
	my $id = shift;

	if (ref $Kephra::app{menu}{$id} eq 'HASH'){
		my $menu = $Kephra::app{menu}{$id};

		if ($menu->{absolete} and $menu->{update})
			{ $menu->{absolete} = 0 if $menu->{update}() ;
			}
 
		if (ref $menu->{onopen} eq 'HASH')
			{ $_->() for values %{$menu->{onopen}}; 
		}

		_get($id);
	}
}
sub set_absolete{ $Kephra::app{menu}{$_[0]}{absolete} = 1 }
sub not_absolete{ $Kephra::app{menu}{$_[0]}{absolete} = 0 }
sub is_absolete { $Kephra::app{menu}{$_[0]}{absolete}     }
sub set_update  { 
	$Kephra::app{menu}{$_[0]}{update} =  $_[1] if ref $_[1] eq 'CODE'
}
sub no_update  {
	delete $Kephra::app{menu}{$_[0]}{update} 
		if exists $Kephra::app{menu}{$_[0]}
}

sub add_onopen_check{
	return until ref $_[2] eq 'CODE';
	$Kephra::app{ menu }{ $_[0] }{onopen}{ $_[1] } = $_[2];
}
sub del_onopen_check{
	return until $_[1];
	delete $Kephra::app{ menu }{ $_[0] }{onopen}{ $_[1] }
		if exists $Kephra::app{ menu }{ $_[0] }{onopen}{ $_[1] };
}

# create on runtime changeable menus
sub create_dynamic {
	my ( $menu_id, $menu_name ) = @_ ;

	#
	if ($menu_name eq '&insert_templates') {
		set_update($menu_id, sub {
			my $cfg = $Kephra::config{file}{templates}; 
			my $file = Kephra::Config::filepath($cfg->{directory}, $cfg->{file});
			my $tmp = Kephra::Config::File::load( $file );
			my @menu_data;
			if (exists $tmp->{template}){
				$tmp = Kephra::Config::Tree::_convert_node_2_AoH(\$tmp->{template});
				for my $template ( @{$tmp} ) {
					my %item;
					$item{type} = 'item';
					$item{label}= $template->{name};
					$item{call} = sub {
						my $filepath = Kephra::Document::_get_current_file_path()
							|| "<$Kephra::localisation{app}{general}{untitled}>";
						my $filename = Kephra::Document::_get_current_name()
							|| "<$Kephra::localisation{app}{general}{untitled}>";
						my $firstname = Kephra::Document::_get_current_firstname()
							|| "<$Kephra::localisation{app}{general}{untitled}>";
						my $content = $template->{content};
						$content =~ s/\[\$\$firstname\]/$firstname/g;
						$content =~ s/\[\$\$filename\]/$filename/g;
						$content =~ s/\[\$\$filepath\]/$filepath/g;
						Kephra::Edit::insert_text($content);
					};
					$item{help}= $template->{description};
					push @menu_data, \%item; 
				}
			}
			eval_data($menu_id, \@menu_data);
		});

		set_absolete($menu_id);

	} elsif ($menu_name eq '&file_history'){

		Kephra::API::EventTable::add_call (
			'document.list', 'menu_'.$menu_id, sub { set_absolete($menu_id); }
		);

		set_update($menu_id, sub {
			my @menu_data;
			for my $file ( @{ Kephra::File::History::get() } ){
				my %item;
				$item{type} = 'item';
				$item{label}= ( File::Spec->splitpath( $file ) )[2];
				$item{help}= $file;
				my $cmd = 'sub {Kephra::Document::Internal::add(\''.$file.'\')}';
				$item{call} = eval $cmd;
				push @menu_data, \%item; 
			}
			eval_data($menu_id, \@menu_data);
		});

		set_absolete($menu_id);

	} elsif ($menu_name eq '&document_change'){

		Kephra::API::EventTable::add_call (
			'document.list', 'menu_'.$menu_id, sub { set_absolete($menu_id) }
		);

		set_update( $menu_id, sub {
			return unless exists $Kephra::temp{document}{buffer};
			my $filenames = Kephra::Document::_get_all_names();
			my $pathes = Kephra::Document::_get_all_pathes();
			my $untitled = $Kephra::localisation{app}{general}{untitled};
			my $space = ' ';
			my @menu_data;
			for my $nr (0 .. @$filenames-1){
				my $item = \%{$menu_data[$nr]};
				$space = '' if $nr == 9;
				$item->{type} = 'radioitem';
				$item->{label} = $filenames->[$nr] 
					? $space.($nr+1)." - $filenames->[$nr] \t - $pathes->[$nr]"
					: $space.($nr+1)." - <$untitled> \t -";
				$item->{call} = eval 'sub {Kephra::Document::Change::to_nr('.$nr.')}';
			}
			eval_data($menu_id, \@menu_data);
		});

		add_onopen_check( $menu_id, 'select', sub {
			my $menu = _get($menu_id);
			my $check_nr = Kephra::Document::_get_current_nr();
			$menu->FindItemByPosition($check_nr)->Check(1);
		});

		set_absolete($menu_id);
	}

}

# create colid, not on runtime changeable menus
sub create_static{
	my ($menu_id, $menu_def) = @_;

	return unless ref $menu_def eq 'ARRAY';
	not_absolete($menu_id);
	eval_data($menu_id, assemble_data_from_def($menu_def));
}

# make menu data structures (MDS) from menu skeleton definitions (command list)
sub assemble_data_from_def {
	my $menu_def = shift;
	return unless ref $menu_def eq 'ARRAY';

	my $menu_label = $Kephra::localisation{app}{menu};
	my ($cmd_name, $cmd_data, $type_name, $pos, $sub_id);
	my @mds = (); # menu data structure
	for my $item_def (@$menu_def){
		my %item;
		# creating separator
		if (not defined $item_def){
			$item{type} = ''
		# sorting commented lines out
		} elsif (substr($item_def, -1) eq '#'){
			next;
		# creating separator
		} elsif ($item_def eq '' or $item_def eq 'separator') {
			$item{type} = ''
		# eval a sublist
		} elsif (ref $item_def eq 'HASH'){
			$sub_id = $_ for keys %$item_def;
			$pos = index $sub_id, ' ';
			# make submenu if keyname is without command
			if ($pos == -1){
				$item{type} = 'menu';
				$item{id} = $sub_id;
				$item{label} = $menu_label->{$sub_id};
				$item{data} = assemble_data_from_def($item_def->{$sub_id}); 
			} else {
				$item{type} = substr $sub_id, 0, $pos;
				$cmd_name = substr $sub_id, $pos+1;
				# make submenu when finding the menu command
				if ($item{type} eq 'menu'){
					$item{id}   = $cmd_name;
					$item{label}= $menu_label->{$cmd_name};
					$item{data} = assemble_data_from_def($item_def->{$sub_id}); 
				}
			}
		# menu items
		} else {
			$pos = index $item_def, ' ';
			next if $pos == -1;
			$item{type} = substr $item_def, 0, $pos;
			$cmd_name = substr $item_def, $pos+1;
			if ($item{type} eq 'menu'){
				$item{id} = $cmd_name;
				$item{label}= $Kephra::localisation{app}{menu}{$cmd_name};
			} else {
				$cmd_data = Kephra::API::CommandList::get_cmd_properties( $cmd_name );
				# skipping when command call is missing
				next unless ref $cmd_data and exists $cmd_data->{call};
				for ('call','enable','state','label','help','icon'){
					$item{$_} = $cmd_data->{$_} if $cmd_data->{$_}
				}
			}
		}
		push @mds, \%item;
	}
	return \@mds;
}


# eval menu data structures (MDS) to wxMenus
sub eval_data {
	my $menu_id = shift;
	return unless defined $menu_id;

	#emty the old or create new menu under the given ID
	my $menu = _get($menu_id);
	if (defined $menu) {
		$menu->Delete( $_ ) for $menu->GetMenuItems;
	} else { 
		$menu = Wx::Menu->new();
	}

	my $menu_data = shift;

	unless (ref $menu_data eq 'ARRAY') {
		_set($menu_id, $menu); 
		return $menu;
	}
	my $win = Kephra::App::Window::_get();

	my $kind;
	my $item_id = exists $Kephra::app{menu}{$menu_id}{item_id}
		? $Kephra::app{menu}{$menu_id}{item_id}
		: $Kephra::app{GUI}{masterID}++ * 100;
	$Kephra::app{menu}{$menu_id}{item_id} = $item_id;

	for my $item_data (@$menu_data){
		if (not $item_data->{type} or $item_data->{type} eq 'separator'){
			$menu->AppendSeparator;
		} elsif ($item_data->{type} eq 'menu'){
			if (ref $item_data->{data} eq 'ARRAY'){
				$menu->Append( $item_id++, $item_data->{label}, 
						eval_data( $item_data->{id}, $item_data->{data} ));
			} elsif ( $item_data->{id} and $item_data->{label}){
				$menu->Append
					($item_id++, $item_data->{label}, ready( $item_data->{id} ));
			}
		} else {
			if      ($item_data->{type} eq 'checkitem'){
				$kind = wxITEM_CHECK
			} elsif ($item_data->{type} eq 'radioitem'){
				$kind = wxITEM_RADIO
			} elsif ($item_data->{type} eq 'item'){
				$kind = wxITEM_NORMAL 
			} else { next; }
	
			my $menu_item = Wx::MenuItem->new
				($menu, $item_id, $item_data->{label}, '', $kind);
			$menu_item->SetBitmap( $item_data->{icon} ) 
				if ref $item_data->{icon} eq 'Wx::Bitmap'
				and $item_data->{type} eq 'item';
			
			add_onopen_check( $menu_id, 'enable_'.$item_id, sub {
				$menu_item->Enable( $item_data->{enable}() );
			} ) if ref $item_data->{enable} eq 'CODE';
			add_onopen_check( $menu_id, 'check_'.$item_id, sub {
				$menu_item->Check( $item_data->{state}() )
			} ) if ref $item_data->{state} eq 'CODE';

			EVT_MENU          ($win, $item_id, $item_data->{call} );
			EVT_MENU_HIGHLIGHT($win, $item_id, sub {
				Kephra::App::StatusBar::info_msg( $item_data->{help} )
			});
			$menu->Append( $menu_item );
			$item_id++; 
		}
	1; #sucess
	}

	Kephra::API::EventTable::add_call
		('menu.open', 'menu_'.$menu, sub {ready($menu_id)} );
	_set($menu_id, $menu);
	return $menu;
}

1;