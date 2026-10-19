# Security policy

## Reporting a problem

Please **don't open a public issue** for security problems. Use GitHub's private
reporting instead: [Report a vulnerability](https://github.com/sthrnilshaaa/fourpages/security/advisories/new).

Include what you found, how to reproduce it, and the app version
(Settings › About). You'll get an answer as soon as possible; fixes ship in the
next release, and you'll be credited unless you'd rather not be.

## Supported versions

Only the latest release gets security fixes.

## Scope

Fourpages works offline and keeps everything on the device. The parts that
talk to the network are: the update check (GitHub API), the
optional dictionary lookup (dictionaryapi.dev), and links you open yourself.
Problems with opening malicious EPUB, PDF or DOCX files (crashes, file access
outside the app, script execution in the reader) are in scope.
