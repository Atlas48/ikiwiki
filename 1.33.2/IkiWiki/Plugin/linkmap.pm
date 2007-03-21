#!/usr/bin/perl
package IkiWiki::Plugin::linkmap;

use warnings;
use strict;
use IkiWiki;
use IPC::Open2;

sub import { #{{{
	hook(type => "preprocess", id => "linkmap", call => \&preprocess);
	hook(type => "format", id => "linkmap", call => \&format);
} # }}}

my $mapnum=0;
my %maps;

sub preprocess (@) { #{{{
	my %params=@_;

	$params{pages}="*" unless defined $params{pages};
	
	# Needs to update whenever a page is added or removed, so
	# register a dependency.
	add_depends($params{page}, $params{pages});
	
	# Can't just return the linkmap here, since the htmlscrubber
	# scrubs out all <object> tags (with good reason!)
	# Instead, insert a placeholder tag, which will be expanded during
	# formatting.
	$mapnum++;
	$maps{$mapnum}=\%params;
	return "<div class=\"linkmap$mapnum\"></div>";
} # }}}

sub format (@) { #{{{
        my %params=@_;

	$params{content}=~s/<div class=\"linkmap(\d+)"><\/div>/genmap($1)/eg;

        return $params{content};
} # }}}

sub genmap ($) { #{{{
	my $mapnum=shift;
	return "" unless exists $maps{$mapnum};
	my %params=%{$maps{$mapnum}};

	# Get all the items to map.
	my %mapitems = ();
	foreach my $item (keys %links) {
		if (pagespec_match($item, $params{pages})) {
			my $link=htmlpage($item);
			$link=IkiWiki::abs2rel($link, IkiWiki::dirname($params{page}));
			$mapitems{$item}=$link;
		}
	}

	# Use ikiwiki's function to create the file, this makes sure needed
	# subdirs are there and does some sanity checking.
	will_render($params{page}, $params{page}.".png");
	writefile($params{page}.".png", $config{destdir}, "");

	# Run dot to create the graphic and get the map data.
	my $pid;
	my $sigpipe=0;;
	$SIG{PIPE}=sub { $sigpipe=1 };
	$pid=open2(*IN, *OUT, "dot -Tpng -o '$config{destdir}/$params{page}.png' -Tcmapx");
	
	# open2 doesn't respect "use open ':utf8'"
	binmode (IN, ':utf8'); 
	binmode (OUT, ':utf8'); 

	print OUT "digraph linkmap$mapnum {\n";
	print OUT "concentrate=true;\n";
	print OUT "charset=\"utf-8\";\n";
	print OUT "ratio=compress;\nsize=\"".($params{width}+0).", ".($params{height}+0)."\";\n"
		if defined $params{width} and defined $params{height};
	foreach my $item (keys %mapitems) {
		print OUT "\"$item\" [shape=box,href=\"$mapitems{$item}\"];\n";
		foreach my $link (map { bestlink($item, $_) } @{$links{$item}}) {
			print OUT "\"$item\" -> \"$link\";\n"
				if $mapitems{$link};
		}
	}
	print OUT "}\n";
	close OUT;

	local $/=undef;
	my $ret="<object data=\"".
	       IkiWiki::abs2rel("$params{page}.png", IkiWiki::dirname($params{page})).
	       "\" type=\"image/png\" usemap=\"#linkmap$mapnum\">\n".
	        <IN>.
	        "</object>";
	close IN;
	
	waitpid $pid, 0;
	$SIG{PIPE}="DEFAULT";
	if ($sigpipe) {
		return  "[[linkmap failed to run dot]]";
	}

	return $ret;
} #}}}

1
