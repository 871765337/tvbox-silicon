# Notes for coding agents

## Building and releasing

- **Pull from the remote before you build or release.** Run `git fetch origin`, then bring `main` up to date with
  `git pull --ff-only` (or `git rebase origin/main` if you have local commits). Autofix PRs and other sessions merge
  into `main` often. A build made from an out-of-date tree ships without their fixes and has to be rebuilt and
  notarized again, which costs 25 minutes or more.
- Check again right before publishing (`git fetch origin && git merge-base --is-ancestor origin/main HEAD`). If
  `origin/main` moved during the build, pull and rebuild. Never deploy the website or push from a tree behind it.
