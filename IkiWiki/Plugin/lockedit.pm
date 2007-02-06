#!/usr/bin/perl
package IkiWiki::Plugin::lockedit;

use warnings;
use strict;
use IkiWiki;

sub import { #{{{
	hook(type => "canedit", id => "lockedit", call => \&canedit);
	hook(type => "formbuilder_setup", id => "lockedit",
	     call => \&formbuilder_setup);
} # }}}

sub canedit ($$) { #{{{
	my $page=shift;
	my $cgi=shift;
	my $session=shift;

	my $user=$session->param("name");
	return undef if defined $user && IkiWiki::is_admin($user);

	foreach my $admin (@{$config{adminuser}}) {
		if (pagespec_match($page, IkiWiki::userinfo_get($admin, "locked_pages"), "")) {
			return sprintf(gettext("%s is locked by %s and cannot be edited"),
				htmllink("", "", $page, 1),
				IkiWiki::userlink($admin));
		}
	}

	return undef;
} #}}}

sub formbuilder_setup (@) { #{{{
	my %params=@_;
	
	my $form=$params{form};
	my $session=$params{session};
	my $cgi=$params{cgi};
	my $user_name=$session->param("name");

	if ($form->title eq "preferences") {
		$form->field(name => "locked_pages", size => 50,
			comment => "(".htmllink("", "", "PageSpec", 1).")");
		if (! IkiWiki::is_admin($user_name)) {
			$form->field(name => "locked_pages", type => "hidden");
		}
		if (! $form->submitted) {
			$form->field(name => "locked_pages", force => 1,
				value => IkiWiki::userinfo_get($user_name, "locked_pages"));
		}
		if ($form->submitted && $form->submitted eq 'Save Preferences') {
			if (defined $form->field("locked_pages")) {
				IkiWiki::userinfo_set($user_name, "locked_pages",
					$form->field("locked_pages")) ||
						error("failed to set locked_pages");
			}
		}
	}
} #}}}

1
