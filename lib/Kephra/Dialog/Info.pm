package Kephra::Dialog::Info;
$VERSION = '0.05';

use strict;
use Wx qw(wxSYSTEM_MENU wxCAPTION wxMINIMIZE_BOX wxCLOSE_BOX
          wxBOTH wxVERSION_STRING
    );

sub combined {
	return simple();

	my $info_win = Wx::Frame->new(
		Kephra::App::Window::_get(), -1,
		" Info About Kephra",
		[ 100, 100 ],
		[ 460, 260 ],
		wxSYSTEM_MENU | wxCAPTION | wxMINIMIZE_BOX | wxCLOSE_BOX,
	);
	Kephra::App::Window::load_icon( $info_win,
		$Kephra::config{'app'}{'window'}{'icon'} );
	$info_win->SetBackgroundColour( Wx::Colour->new( 0xed, 0xeb, 0xdb ) );

	$info_win->Centre(wxBOTH);
	$info_win->Show(1);
}

sub simple {
	my $info = $Kephra::localisation{'dialog'}{'info'};
	my $sciv = 'Scintilla ';
	my $v = substr(wxVERSION_STRING ,-5);
	if    ($v eq '2.4.2'){$sciv .= '1.54'}
	elsif ($v eq '2.6.2'){$sciv .= '1.62'}
	elsif ($v eq '2.6.3'){$sciv .= '1.62'}
	elsif ($v eq '2.8.4'){$sciv .= '1.70'}
	my $content = "Perfect Coding Enviroment "
		. "$info->{mady_by}  Herbert Breunung\n\n"
		. "$info->{licensed} GPL (GNU Public License) \n"
		. " ( $info->{detail} \n   $info->{more} ) \n"
		. "$info->{homepage}  http:\\\\proton-ce.sf.net\n\n"
		. "$info->{contains}: \n"
		. " - Perl ". substr($],0,1).'.'.substr($],4,1).'.'.substr($],7,1)."\n"
		. " - WxPerl $Wx::VERSION $info->{wrappes} \n"
		. "   - " . wxVERSION_STRING . " $info->{and} $sciv\n"
		. " - Config::General $Config::General::VERSION \n"
		. " - YAML $YAML::VERSION \n"
		."\n\n $info->{dedication}"
		. "";
	my $title = "$info->{title} $Kephra::NAME $Kephra::VERSION";
	$title .=  ' pl ' . $Kephra::PATCHLEVEL if $Kephra::PATCHLEVEL;
	Kephra::Dialog::msg_box( Kephra::App::Window::_get(), $content, $title );
}

1;
