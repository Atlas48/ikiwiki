[[!template id=plugin name=emailauth core=1 author="[[Joey]]"]]
[[!tag type/auth]]

This plugin lets users log into ikiwiki using any email address. To complete
the login, a one-time-use link is emailed to the user, and they can simply
open that link in their browser.

It is enabled by default, but can be turned off if you want to only use
some other form of authentication, such as [[passwordauth]] or [[openid]].

Users who have logged in using emailauth will have their email address used as
their username. In places where the username is displayed, like the
RecentChanges page, the domain will be omitted, to avoid exposing the
user's email address.

This plugin needs the [[!cpan Mail::SendMail]] perl module installed,
and able to send outgoing email.