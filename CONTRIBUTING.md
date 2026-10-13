# Contributing

Issues and pull requests are welcome. For a proposed behavior change, describe
the use case and expected result before changing the command or templates.

1. Use Bash 3.2-compatible syntax in the command, build tools, installer, and
   tests. Keep the runtime limited to Bash, Git, and the documented Unix tools.
2. Edit `src/git-agent.sh` or `templates/` as the source of truth. Then build the
   checked-in `bin/git-agent` using the procedure in
   [README.md](README.md#build-and-verification). Keep generated output in sync.
3. Run `bash tools/build.sh`, `bash tests/run.sh`, and `bash tools/smoke.sh`.
   Describe which supported environments you checked and any skipped cases.
4. Submit a focused pull request explaining behavior, compatibility, and
   relevant test evidence. Do not commit secrets, credentials, or private
   project material.

For security reports, use [SECURITY.md](SECURITY.md) instead of a public issue.
