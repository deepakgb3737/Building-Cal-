# GitHub Publication Checklist

## Attribution

README.md and NOTICE.md state that the implementation used AI assistance while
the calculation formulas, business rules and requirements came from the team.
Third-party authorship and the bundled MIT license remain separate.

## Before Uploading

- Confirm the destination repository and whether it should be public or private.
- Preserve the owner's existing root MIT license from the destination repository.
- Confirm distribution rights for icons, fonts and supplied reference assets.
- Review every staged file for secrets, private project notes and device details.
- Keep pubspec.lock: this is an application, and its dependency resolution should
  be reproducible.
- Keep source, assets, tests, platform configuration, README.md, RULES.md and
  AGENTS.md. Keep packages/easy_floor/LICENSE with the reference package.
- Exclude build output, SDK caches, local.properties, signing credentials,
  environment secrets and local .codex state using the supplied ignore rules.
- Attach APKs to a release if desired rather than committing build directories.

## Verify

```sh
flutter pub get
flutter analyze
flutter test
```

Latest source verification before this documentation-only preparation: 765 tests
passed. Analysis had no errors or warnings and 62 existing informational notices,
which make the default analysis command exit nonzero. See the EasyFloor audit
documents for scenario-specific limitations; passing tests do not certify every
device or real-world calculation.

## Upload

The owner confirmed the public destination:
https://github.com/deepakgb3737/Building-Cal-.
The remote already had an initial README and MIT license. Publication uses a
temporary clone and a normal commit on top of that history, preserving LICENSE;
it does not force-push or initialize unrelated history over the remote.
The original Flutter workspace is not automatically converted into a Git clone.
