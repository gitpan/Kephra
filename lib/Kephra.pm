# See end of file for docs, -NI = not implemented or used, -DEP = depreciated

package Kephra;

use 5.006;
use strict;

our $NAME       = __PACKAGE__; # name of entire application
our $VERSION    = '0.3.9.6';   # version of entire app
our $PATCHLEVEL;
our $STANDALONE;
our @ISA        = 'Wx::App';   # $NAME is a wx application

# Configuration Phase
use Cwd;
use File::Spec::Functions ':ALL';
use File::HomeDir    ();
use File::UserConfig ();
use Config::General  ();
use YAML             ();

use Wx;                         # Core wxWidgets Framework
use Wx::STC;                    # Scintilla editor component
use Wx::DND;                    # Drag'n Drop & Clipboard support (only K::File)
#use Wx::Print;                 # Print cd..Support (used only in Kephra::File )
#use Text::Wrap                 # for text formating

# these will used in near future
#use Perl::Tidy;                # -NI perl formating
#use PPI ();                    # For refactoring support
#use Params::Util ();           # Parameter checking
#use Class::Inspector ();       # Class checking

# used internal modules, parts of kephra
use Kephra::API::CommandList;      # UI API
use Kephra::API::EventTable;       # internal app API
use Kephra::API::Extension;        # Plugin API
use Kephra::App;                   # App start & shut down sequence
use Kephra::App::ContextMenu;      # contextmenu manager
use Kephra::App::EditPanel;        #
use Kephra::App::EditPanel::Margin;#
use Kephra::App::MainToolBar;      #
use Kephra::App::Menu;             # base menu builder
use Kephra::App::MenuBar;          # main menu
use Kephra::App::ToolBar;          # base toolbar builder
use Kephra::App::SearchBar;        # Toolbar for searching and navigation
use Kephra::App::StatusBar;        #
use Kephra::App::TabBar;           # API 2 Wx::Notebook
use Kephra::App::Window;           # API 2 Wx::Frame and more
use Kephra::Config;                # low level config manipulation
#use Kephra::Config::Embedded;     # build in emergency settings
use Kephra::Config::File;          # API 2 ConfigParser: Config::General, YAML
use Kephra::Config::Global;        # API 4 config, general content level
use Kephra::Config::Interface;     #
use Kephra::Config::Tree;          #
use Kephra::Dialog;                # API 2 dialogs, fileselectors, msgboxes
#require Kephra::Dialog::Config;   # config dialog
#require Kephra::Dialog::Exit;     # select files to be saved while exit program
#require Kephra::Dialog::Info;     # info box
#require Kephra::Dialog::Keymap;   #
#require Kephra::Dialog::Notify    # inform about filechanges from outside
#require Kephra::Dialog::Search;   # find and replace dialog
use Kephra::Document;              # document menu funktions
use Kephra::Document::Change;      # calls for changing current doc
use Kephra::Document::Internal;    # doc handling helper methods
use Kephra::Document::SyntaxMode;  # doc handling helper methods
use Kephra::Edit;                  # basic edit menu funktions
use Kephra::Edit::Comment;         # comment functions
use Kephra::Edit::Convert;         # convert functions
use Kephra::Edit::Format;          # formating functions
use Kephra::Edit::History;         # undo redo etc.
use Kephra::Edit::Goto;            # editpanel textcursor navigation
use Kephra::Edit::Search;          # search menu functions
use Kephra::Edit::Select;          # text selection
use Kephra::Edit::Bookmark;        # doc spanning bookmarks
use Kephra::File;                  # file menu functions
use Kephra::File::History;         # list of recent used Files
use Kephra::File::IO;              # API 2 FS, read write files
use Kephra::File::Session;         # file session handling
use Kephra::Module;                # Module Handling
use Kephra::Show;                  # -DEP display content: files

# global data
our %app;           # ref to app parts and app data for GUI, Events, Parser
our %config;        # global settings, saved in /config/global/autosaved.conf
our %document;      # data of current documents, to be stored in session file
our %help;          # -NI locations of documentation files in current language
our %temp;          # global internal temp data
our %localisation;  # all localisation strings in your currently selected lang
our %syntaxmode;    # -NI

sub user_config {
	$_[0] and $_[0] eq $NAME and shift;
	File::UserConfig->new(@_);
}

sub configdir {
	$_[0] and $_[0] eq $NAME and shift;
	File::UserConfig->configdir(@_);
}

# Wx App Events
sub OnInit { &Kephra::App::start }   # boot app: init core and load config files
sub quit   { &Kephra::App::exit  }   # save files & settings as configured

1;

__END__

=head1 NAME

Kephra - crossplatform, CPAN-installable GUI-Texteditor along perllike Paradigms 

=head1 DISCLAIMER

This App do currently not install fully from cpan shell but I do my best to 
change that ASAP. Now its just on CPAN for people who want to help ME. *g*

=head1 SYNOPSIS

    > kephra [<files>]   # start with certain files open

=head1 DESCRIPTION

This module install's a complete editor application with all its configs
and documentation for your programming, web and text authoring. 

=head2 Philosophy

I know, i know, there are plenty text editors out there, even some really
mighty IDE, but this is my attempt to make it better. And by that i don't
meant to make a better vi or emacs nor kommodo, but to carry over to text
editing, what makes perl a great language: A low entry barrier, a high end
and to have a choice between different styles, like the vi command line
input style, the emacs keyboard combinations style and the GUI style. We're
currently not that far but already achieved a good portion.

The other thing is that CPAN, perl's great toolbox, has already many modules,
that cover most of the feature, a good IDE needs today. Why don't we use it
for our own programming?

The third pillar idea will become more important after 0.4.5 or so. In the
end you know best what you want. It should be easy to extend your most 
important tool as a programmer to get your ideas working in a fast manner.

=head2 Features

Beside all the basic stuff that would you expect from a notepad, we have
file sessions, simple templates, recent closed files, and file functions
applied to all files, where it makes sense.

We have also a pile of advanced text navigation (on braces or blockwise),
goto last edit or 10 doc spanning Bookmarks as well as find in files. 

Advanced undo, line editing (edit functions that take the current line as
input), move selected text by mouse or keyboard. Formating funtions like 
blockformat, align blocks, indenting, commenting ...

Documents have several properties like syntax styling, auto indention, tab
width, tab use, write protection.

View options contain switches for any GUI element and marker for: current
line, end of line bytes, right margin, indetion guides, bracehiglighting,
line wrap and font.

Every menu and toolbar is evaluated from a simple yaml file, so you can 
change it easily by opening this files from the config menu.

=head1 TO DO

- Complete CPANification

=head2 Stable Release 0.4

This release is about getting the editor liquid or highly configurable.
Its also about improvements in the user interface and of course the little
things we missed. And its about time that it will released so that can we 
can concentrate more on features for coding support.

=head2 Stable Release 0.5

Things like output panel, code folding, snippet lib, help integration,
autocompletition and so on. Hope that by the end of 0.4.n series will be
the extention API stable.

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Kephra>

For other issues, contact the author.

More info and resources you find on our sourceforge web page under:

L<http://kephra.sourceforge.net>

=head1 AUTHORS

* Herbert Breunung E<lt>lichtkind@cpan.orgE<gt> (main author)

* Jens Neuwerk E<lt>jenne@gmxpro.netE<gt> (author of icons, GUI advisor)

* Adam Kennedy E<lt>adamk@cpan.orgE<gt> (cpanification)

=head1 COPYRIGHT

This Copyright applies only to the "Kephra" Perl software distribution, not 
the icons bundled within.

Copyright 2004 - 2008 Herbert Breunung.

This program is free software; you can redistribute
it and/or modify it under the terms of the GNU GPL.

The full text of the license can be found in the
LICENSE file included with this module.
    
=cut
