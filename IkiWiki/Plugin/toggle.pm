#!/usr/bin/perl
package IkiWiki::Plugin::toggle;

use warnings;
use strict;
use IkiWiki;

# Here's the javascript that makes this possible. A key feature is the use
# of css to hide toggleables, to avoid any flashing on page load. The css
# is only emitted after the javascript tests that it's going to be able to
# show the toggleables.
my $javascript=<<'EOF';
<script type="text/javascript">
<!--
if (document.getElementById && document.getElementsByTagName && document.createTextNode) {
	document.write('<style type="text/css">div.toggleable { display: none; }</style>');
	window.onload = inittoggle;
}

function inittoggle() {
	var as = getElementsByClass('toggle');
	for (var i = 0; i < as.length; i++) {
		var id = as[i].href.match(/#(\w.+)/)[1];
		document.getElementById(id).style.display="none";
		as[i].onclick = function() {
			toggle(this);
			return false;
		}
	}
}

function toggle(s) {
	var id = s.href.match(/#(\w.+)/)[1];
	style = document.getElementById(id).style;
	if (style.display == "none")
		style.display = "block";
	else
		style.display = "none";
}

function getElementsByClass(class) {
	var ret = new Array();
	var pattern = new RegExp("(^|\\s)"+class+"(\\s|$)");
	var els = document.getElementsByTagName('*');
	for (i = 0, j = 0; i < els.length; i++) {
		if ( pattern.test(els[i].className) ) {
			ret[j] = els[i];
			j++;
		}
	}
	return ret;
}
//-->
</script>
EOF

sub import { #{{{
	hook(type => "preprocess", id => "toggle",
		call => \&preprocess_toggle);
	hook(type => "preprocess", id => "toggleable",
		call => \&preprocess_toggleable, scan => 1);
	hook(type => "format", id => "toggle", call => \&format);
} # }}}

sub genid ($$) { #{{{
	my $page=shift;
	my $id=shift;

	$id="$page.$id";

	# make it a legal html id attribute
	$id=~s/[^-a-zA-Z0-9.]/-/g;
	if ($id !~ /^[a-zA-Z]/) {
		$id="id$id";
	}
	return $id;
} #}}}

sub preprocess_toggle (@) { #{{{
	my %params=(id => "default", text => "more", @_);

	my $id=genid($params{page}, $params{id});
	return "<a class=\"toggle\" href=\"#$id\">$params{text}</a>";
} # }}}

sub preprocess_toggleable (@) { #{{{
	my %params=(id => "default", text => "", @_);

	# Preprocess the text to expand any preprocessor directives
	# embedded inside it. This is why scan is set for this preprocessor
	# directive, since it could expand to something with a link in it.
	$params{text}=IkiWiki::preprocess($params{page}, $params{destpage}, $params{text});
	
	my $id=genid($params{page}, $params{id});

	# Should really be a postprocessor directive, oh well. Work around
	# markdown's dislike of markdown inside a <div>.
	return "<div class=\"toggleable\" id=\"$id\"></div>\n\n$params{text}\n<div class=\"toggleableend\"></div>";
} # }}}

sub format (@) { #{{{
        my %params=@_;

	if ($params{content}=~s!(<div class="toggleable" id="[^"]+">)</div>!$1!g) {
		$params{content}=~s/<div class="toggleableend">//g;
		$params{content}=~s!^<\/body>!$javascript</body>!m;
	}
	return $params{content};
} # }}}

1
