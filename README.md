# Utilities

### Dependencies
#### External
1. [Homebrew](https://brew.sh/)
2. [rbenv](https://github.com/rbenv/rbenv)
3. [ruby-build](https://github.com/rbenv/ruby-build)
4. [GPG](https://www.gnupg.org/) - see [GPG Suite](https://gpgtools.org/) for Mac
5. [Perlbrew](https://perlbrew.pl/)
6. [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-install-macos.html)
7. [saml2aws](https://github.com/Versent/saml2aws)

On Mac, most of the above software can be managed with Homebrew.

### About
This is a set of small shell scripts used to simplify common tasks, such as:
- keeping Homebrew (Mac only)*, Python & Python Installed Packages (PIP), Perl &
  Ruby up-to-date
- decoding Amazon Kinesis data blocks
- keeping AWS SAML sessions active
- verifying the integrity of downloaded files

Instructions for each script are at the top of the file.  Simply run each script
without arguments - if arguments are required, a usage string will be printed to
the console.

<sup>*__Please Note:__  The `BrewUpdate.sh` script will attempt to update GUI
programs managed via `cask-upgrade` as well as standard Homebrew packages.  If
running this via a cron job, the script will execute but will not update casks
requiring a password.  Ensure you allow cron to send you job summary emails -
they will show these casks as '__OUTDATED__'.  Re-run the script by hand and
supply the necessary password when required.</sup>
