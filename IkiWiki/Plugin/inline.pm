#!/usr/bin/perl
# Page inlining and blogging.
package IkiWiki::Plugin::inline;

use warnings;
use strict;
use Encode;
use IkiWiki 2.00;
use URI;

my %knownfeeds;
my %page_numfeeds;
my @inline;

sub import { #{{{
	hook(type => "getopt", id => "inline", call => \&getopt);
	hook(type => "checkconfig", id => "inline", call => \&checkconfig);
	hook(type => "sessioncgi", id => "inline", call => \&sessioncgi);
	hook(type => "preprocess", id => "inline", 
		call => \&IkiWiki::preprocess_inline);
	hook(type => "pagetemplate", id => "inline",
		call => \&IkiWiki::pagetemplate_inline);
	hook(type => "format", id => "inline", call => \&format);
	# Hook to change to do pinging since it's called late.
	# This ensures each page only pings once and prevents slow
	# pings interrupting page builds.
	hook(type => "change", id => "inline", 
		call => \&IkiWiki::pingurl);

} # }}}

sub getopt () { #{{{
	eval q{use Getopt::Long};
	error($@) if $@;
	Getopt::Long::Configure('pass_through');
	GetOptions(
		"rss!" => \$config{rss},
		"atom!" => \$config{atom},
		"allowrss!" => \$config{allowrss},
		"allowatom!" => \$config{allowatom},
	);
}

sub checkconfig () { #{{{
	if (($config{rss} || $config{atom}) && ! length $config{url}) {
		error(gettext("Must specify url to wiki with --url when using --rss or --atom"));
	}
	if ($config{rss}) {
		push @{$config{wiki_file_prune_regexps}}, qr/\.rss$/;
	}
	if ($config{atom}) {
		push @{$config{wiki_file_prune_regexps}}, qr/\.atom$/;
	}
} #}}}

sub format (@) { #{{{
        my %params=@_;

	# Fill in the inline content generated earlier. This is actually an
	# optimisation.
	$params{content}=~s{<div class="inline" id="([^"]+)"></div>}{
		delete @inline[$1,]
	}eg;
	return $params{content};
} #}}}

sub sessioncgi () { #{{{
	my $q=shift;
	my $session=shift;

	if ($q->param('do') eq 'blog') {
		my $page=decode_utf8($q->param('title'));
		$page=~s/\///g; # no slashes in blog posts
		# if the page already exists, munge it to be unique
		my $from=$q->param('from');
		my $add="";
		while (exists $IkiWiki::pagecase{lc($from."/".IkiWiki::titlepage($page).$add)}) {
			$add=1 unless length $add;
			$add++;
		}
		$q->param('page', $page.$add);
		# now go create the page
		$q->param('do', 'create');
		IkiWiki::cgi_editpage($q, $session);
		exit;
	}
}

# Back to ikiwiki namespace for the rest, this code is very much
# internal to ikiwiki even though it's separated into a plugin.
package IkiWiki;

my %toping;
my %feedlinks;

sub yesno ($) { #{{{
	my $val=shift;
	return (defined $val && lc($val) eq "yes");
} #}}}

sub preprocess_inline (@) { #{{{
	my %params=@_;
	
	if (! exists $params{pages}) {
		return "";
	}
	my $raw=yesno($params{raw});
	my $archive=yesno($params{archive});
	my $rss=(($config{rss} || $config{allowrss}) && exists $params{rss}) ? yesno($params{rss}) : $config{rss};
	my $atom=(($config{atom} || $config{allowatom}) && exists $params{atom}) ? yesno($params{atom}) : $config{atom};
	my $quick=exists $params{quick} ? yesno($params{quick}) : 0;
	my $feeds=exists $params{feeds} ? yesno($params{feeds}) : !$quick;
	my $feedonly=yesno($params{feedonly});
	if (! exists $params{show} && ! $archive) {
		$params{show}=10;
	}
	my $desc;
	if (exists $params{description}) {
		$desc = $params{description} 
	} else {
		$desc = $config{wikiname};
	}
	my $actions=yesno($params{actions});
	if (exists $params{template}) {
		$params{template}=~s/[^-_a-zA-Z0-9]+//g;
	}
	else {
		$params{template} = $archive ? "archivepage" : "inlinepage";
	}

	my @list;
	foreach my $page (keys %pagesources) {
		next if $page eq $params{page};
		if (pagespec_match($page, $params{pages}, location => $params{page})) {
			push @list, $page;
		}
	}

	if (exists $params{sort} && $params{sort} eq 'title') {
		@list=sort @list;
	}
	elsif (exists $params{sort} && $params{sort} eq 'mtime') {
		@list=sort { $pagemtime{$b} <=> $pagemtime{$a} } @list;
	}
	elsif (! exists $params{sort} || $params{sort} eq 'age') {
		@list=sort { $pagectime{$b} <=> $pagectime{$a} } @list;
	}
	else {
		return sprintf(gettext("unknown sort type %s"), $params{sort});
	}

	if (yesno($params{reverse})) {
		@list=reverse(@list);
	}

	if (exists $params{skip}) {
		@list=@list[$params{skip} .. scalar @list - 1];
	}
	
	if ($params{show} && @list > $params{show}) {
		@list=@list[0..$params{show} - 1];
	}

	add_depends($params{page}, $params{pages});
	# Explicitly add all currently displayed pages as dependencies, so
	# that if they are removed or otherwise changed, the inline will be
	# sure to be updated.
	add_depends($params{page}, join(" or ", @list));

	my $feednum="";

	my $feedid=join("\0", map { $_."\0".$params{$_} } sort keys %params);
	if (exists $knownfeeds{$feedid}) {
		$feednum=$knownfeeds{$feedid};
	}
	else {
		if (exists $page_numfeeds{$params{destpage}}) {
			if ($feeds) {
				$feednum=$knownfeeds{$feedid}=++$page_numfeeds{$params{destpage}};
			}
		}
		else {
			$feednum=$knownfeeds{$feedid}="";
			if ($feeds) {
				$page_numfeeds{$params{destpage}}=1;
			}
		}
	}

	my $rssurl=basename(rsspage($params{destpage}).$feednum) if $feeds && $rss;
	my $atomurl=basename(atompage($params{destpage}).$feednum) if $feeds && $atom;
	my $ret="";

	if ($config{cgiurl} && ! $params{preview} && (exists $params{rootpage} ||
			(exists $params{postform} && yesno($params{postform})))) {
		# Add a blog post form, with feed buttons.
		my $formtemplate=template("blogpost.tmpl", blind_cache => 1);
		$formtemplate->param(cgiurl => $config{cgiurl});
		$formtemplate->param(rootpage => 
			exists $params{rootpage} ? $params{rootpage} : $params{page});
		$formtemplate->param(rssurl => $rssurl) if $feeds && $rss;
		$formtemplate->param(atomurl => $atomurl) if $feeds && $atom;
		if (exists $params{postformtext}) {
			$formtemplate->param(postformtext =>
				$params{postformtext});
		}
		else {
			$formtemplate->param(postformtext =>
				gettext("Add a new post titled:"));
		}
		$ret.=$formtemplate->output;
	}
	elsif ($feeds && !$params{preview}) {
		# Add feed buttons.
		my $linktemplate=template("feedlink.tmpl", blind_cache => 1);
		$linktemplate->param(rssurl => $rssurl) if $rss;
		$linktemplate->param(atomurl => $atomurl) if $atom;
		$ret.=$linktemplate->output;
	}
	
	if (! $feedonly) {
		require HTML::Template;
		my @params=IkiWiki::template_params($params{template}.".tmpl", blind_cache => 1);
		if (! @params) {
			return sprintf(gettext("nonexistant template %s"), $params{template});
		}
		my $template=HTML::Template->new(@params) unless $raw;
	
		foreach my $page (@list) {
			my $file = $pagesources{$page};
			my $type = pagetype($file);
			if (! $raw || ($raw && ! defined $type)) {
				unless ($archive && $quick) {
					# Get the content before populating the
					# template, since getting the content uses
					# the same template if inlines are nested.
					my $content=get_inline_content($page, $params{destpage});
					$template->param(content => $content);
				}
				$template->param(pageurl => urlto(bestlink($params{page}, $page), $params{destpage}));
				$template->param(title => pagetitle(basename($page)));
				$template->param(ctime => displaytime($pagectime{$page}, $params{timeformat}));
				$template->param(first => 1) if $page eq $list[0];
				$template->param(last => 1) if $page eq $list[$#list];
	
				if ($actions) {
					my $file = $pagesources{$page};
					my $type = pagetype($file);
					if ($config{discussion}) {
						my $discussionlink=gettext("discussion");
						if ($page !~ /.*\/\Q$discussionlink\E$/ &&
						    (length $config{cgiurl} ||
						     exists $links{$page."/".$discussionlink})) {
							$template->param(have_actions => 1);
							$template->param(discussionlink =>
								htmllink($page,
									$params{destpage},
									gettext("Discussion"),
									noimageinline => 1,
									forcesubpage => 1));
						}
					}
					if (length $config{cgiurl} && defined $type) {
						$template->param(have_actions => 1);
						$template->param(editurl => cgiurl(do => "edit", page => pagetitle($page, 1)));
					}
				}
	
				run_hooks(pagetemplate => sub {
					shift->(page => $page, destpage => $params{destpage},
						template => $template,);
				});
	
				$ret.=$template->output;
				$template->clear_params;
			}
			else {
				if (defined $type) {
					$ret.="\n".
					      linkify($page, $params{destpage},
					      preprocess($page, $params{destpage},
					      filter($page, $params{destpage},
					      readfile(srcfile($file)))));
				}
			}
		}
	}
	
	if ($feeds) {
		if (exists $params{feedshow} && @list > $params{feedshow}) {
			@list=@list[0..$params{feedshow} - 1];
		}
		if (exists $params{feedpages}) {
			@list=grep { pagespec_match($_, $params{feedpages}, location => $params{page}) } @list;
		}
	
		if ($rss) {
			my $rssp=rsspage($params{destpage}).$feednum;
			will_render($params{destpage}, $rssp);
			if (! $params{preview}) {
				writefile($rssp, $config{destdir},
					genfeed("rss",
						$config{url}."/".rsspage($params{destpage}).$feednum, $desc, $params{destpage}, @list));
				$toping{$params{destpage}}=1 unless $config{rebuild};
				$feedlinks{$params{destpage}}=qq{<link rel="alternate" type="application/rss+xml" title="RSS" href="$rssurl" />};
			}
		}
		if ($atom) {
			my $atomp=atompage($params{destpage}).$feednum;
			will_render($params{destpage}, $atomp);
			if (! $params{preview}) {
				writefile($atomp, $config{destdir},
					genfeed("atom", $config{url}."/".atompage($params{destpage}).$feednum, $desc, $params{destpage}, @list));
				$toping{$params{destpage}}=1 unless $config{rebuild};
				$feedlinks{$params{destpage}}=qq{<link rel="alternate" type="application/atom+xml" title="Atom" href="$atomurl" />};
			}
		}
	}
	
	return $ret if $raw;
	push @inline, $ret;
	return "<div class=\"inline\" id=\"$#inline\"></div>\n\n";
} #}}}

sub pagetemplate_inline (@) { #{{{
	my %params=@_;
	my $page=$params{page};
	my $template=$params{template};

	$template->param(feedlinks => $feedlinks{$page})
		if exists $feedlinks{$page} && $template->query(name => "feedlinks");
} #}}}

sub get_inline_content ($$) { #{{{
	my $page=shift;
	my $destpage=shift;
	
	my $file=$pagesources{$page};
	my $type=pagetype($file);
	if (defined $type) {
		return htmlize($page, $type,
		       linkify($page, $destpage,
		       preprocess($page, $destpage,
		       filter($page, $destpage,
		       readfile(srcfile($file))))));
	}
	else {
		return "";
	}
} #}}}

sub date_822 ($) { #{{{
	my $time=shift;

	my $lc_time=POSIX::setlocale(&POSIX::LC_TIME);
	POSIX::setlocale(&POSIX::LC_TIME, "C");
	my $ret=POSIX::strftime("%a, %d %b %Y %H:%M:%S %z", localtime($time));
	POSIX::setlocale(&POSIX::LC_TIME, $lc_time);
	return $ret;
} #}}}

sub date_3339 ($) { #{{{
	my $time=shift;

	my $lc_time=POSIX::setlocale(&POSIX::LC_TIME);
	POSIX::setlocale(&POSIX::LC_TIME, "C");
	my $ret=POSIX::strftime("%Y-%m-%dT%H:%M:%SZ", gmtime($time));
	POSIX::setlocale(&POSIX::LC_TIME, $lc_time);
	return $ret;
} #}}}

sub absolute_urls ($$) { #{{{
	# sucky sub because rss sucks
	my $content=shift;
	my $baseurl=shift;

	my $url=$baseurl;
	$url=~s/[^\/]+$//;
	
	$content=~s/(<a(?:\s+(?:class|id)\s*="?\w+"?)?)\s+href=\s*"(#[^"]+)"/$1 href="$baseurl$2"/mig;
	$content=~s/(<a(?:\s+(?:class|id)\s*="?\w+"?)?)\s+href=\s*"(?!\w+:)([^"]+)"/$1 href="$url$2"/mig;
	$content=~s/(<img(?:\s+(?:class|id|width|height)\s*="?\w+"?)*)\s+src=\s*"(?!\w+:)([^"]+)"/$1 src="$url$2"/mig;
	return $content;
} #}}}

sub rsspage ($) { #{{{
	return targetpage(shift, "rss");
} #}}}

sub atompage ($) { #{{{
	return targetpage(shift, "atom");
} #}}}

sub genfeed ($$$$@) { #{{{
	my $feedtype=shift;
	my $feedurl=shift;
	my $feeddesc=shift;
	my $page=shift;
	my @pages=@_;
	
	my $url=URI->new(encode_utf8($config{url}."/".urlto($page,"")));
	
	my $itemtemplate=template($feedtype."item.tmpl", blind_cache => 1);
	my $content="";
	my $lasttime = 0;
	foreach my $p (@pages) {
		my $u=URI->new(encode_utf8($config{url}."/".urlto($p, "")));
		my $pcontent = absolute_urls(get_inline_content($p, $page), $url);

		$itemtemplate->param(
			title => pagetitle(basename($p)),
			url => $u,
			permalink => $u,
			cdate_822 => date_822($pagectime{$p}),
			mdate_822 => date_822($pagemtime{$p}),
			cdate_3339 => date_3339($pagectime{$p}),
			mdate_3339 => date_3339($pagemtime{$p}),
		);

		if ($itemtemplate->query(name => "enclosure")) {
			my $file=$pagesources{$p};
			my $type=pagetype($file);
			if (defined $type) {
				$itemtemplate->param(content => $pcontent);
			}
			else {
				my ($a, $b, $c, $d, $e, $f, $g, $size) = stat(srcfile($file));
				my $mime="unknown";
				eval q{use File::MimeInfo};
				if (! $@) {
					$mime = mimetype($file);
				}
				$itemtemplate->param(
					enclosure => $u,
					type => $mime,
					length => $size,
				);
			}
		}
		else {
			$itemtemplate->param(content => $pcontent);
		}

		run_hooks(pagetemplate => sub {
			shift->(page => $p, destpage => $page,
				template => $itemtemplate);
		});

		$content.=$itemtemplate->output;
		$itemtemplate->clear_params;

		$lasttime = $pagemtime{$p} if $pagemtime{$p} > $lasttime;
	}

	my $template=template($feedtype."page.tmpl", blind_cache => 1);
	$template->param(
		title => $page ne "index" ? pagetitle($page) : $config{wikiname},
		wikiname => $config{wikiname},
		pageurl => $url,
		content => $content,
		feeddesc => $feeddesc,
		feeddate => date_3339($lasttime),
		feedurl => $feedurl,
		version => $IkiWiki::version,
	);
	run_hooks(pagetemplate => sub {
		shift->(page => $page, destpage => $page,
			template => $template);
	});
	
	return $template->output;
} #}}}

sub pingurl (@) { #{{{
	return unless @{$config{pingurl}} && %toping;

	eval q{require RPC::XML::Client};
	if ($@) {
		debug(gettext("RPC::XML::Client not found, not pinging"));
		return;
	}

	# daemonize here so slow pings don't slow down wiki updates
	defined(my $pid = fork) or error("Can't fork: $!");
	return if $pid;
	chdir '/';
	setsid() or error("Can't start a new session: $!");
	open STDIN, '/dev/null';
	open STDOUT, '>/dev/null';
	open STDERR, '>&STDOUT' or error("Can't dup stdout: $!");

	# Don't need to keep a lock on the wiki as a daemon.
	IkiWiki::unlockwiki();

	foreach my $page (keys %toping) {
		my $title=pagetitle(basename($page), 0);
		my $url="$config{url}/".urlto($page, "");
		foreach my $pingurl (@{$config{pingurl}}) {
			debug("Pinging $pingurl for $page");
			eval {
				my $client = RPC::XML::Client->new($pingurl);
				my $req = RPC::XML::request->new('weblogUpdates.ping',
					$title, $url);
				my $res = $client->send_request($req);
				if (! ref $res) {
					debug("Did not receive response to ping");
				}
				my $r=$res->value;
				if (! exists $r->{flerror} || $r->{flerror}) {
					debug("Ping rejected: ".(exists $r->{message} ? $r->{message} : "[unknown reason]"));
				}
			};
			if ($@) {
				debug "Ping failed: $@";
			}
		}
	}

	exit 0; # daemon done
} #}}}

1
