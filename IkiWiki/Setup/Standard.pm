#!/usr/bin/perl
# Standard ikiwiki setup module.
# Parameters to import should be all the standard ikiwiki config stuff,
# plus an array of wrappers to set up.

use warnings;
use strict;
use IkiWiki::Wrapper;
use IkiWiki::Render;

package IkiWiki::Setup::Standard;

sub import {
	IkiWiki::setup_standard(@_);
}
	
package IkiWiki;

sub setup_standard {
	my %setup=%{$_[1]};

	$setup{plugin}=$config{plugin};
	if (exists $setup{add_plugins}) {
		push @{$setup{plugin}}, @{$setup{add_plugins}};
		delete $setup{add_plugins};
	}
	if (exists $setup{exclude}) {
		push @{$config{wiki_file_prune_regexps}}, $setup{exclude};
	}

	if (! $config{render} && (! $config{refresh} || $config{wrappers})) {
		debug(gettext("generating wrappers.."));
		my @wrappers=@{$setup{wrappers}};
		delete $setup{wrappers};
		my %startconfig=(%config);
		foreach my $wrapper (@wrappers) {
			%config=(%startconfig, verbose => 0, %setup, %{$wrapper});
			checkconfig();
			gen_wrapper();
		}
		%config=(%startconfig);
	}
	
	foreach my $c (keys %setup) {
		if (defined $setup{$c}) {
			if (! ref $setup{$c}) {
				$config{$c}=possibly_foolish_untaint($setup{$c});
			}
			elsif (ref $setup{$c} eq 'ARRAY') {
				$config{$c}=[map { possibly_foolish_untaint($_) } @{$setup{$c}}]
			}
			elsif (ref $setup{$c} eq 'HASH') {
				foreach my $key (keys %{$setup{$c}}) {
					$config{$c}{$key}=possibly_foolish_untaint($setup{$c}{$key});
				}
			}
		}
		else {
			$config{$c}=undef;
		}
	}

	if ($config{render}) {
		commandline_render();
	}
	elsif (! $config{refresh}) {
		$config{rebuild}=1;
		debug(gettext("rebuilding wiki.."));
	}
	else {
		debug(gettext("refreshing wiki.."));
	}

	loadplugins();
	checkconfig();
	lockwiki();
	loadindex();
	refresh();

	debug(gettext("done"));
	saveindex();
}

1
