# audacity-drt

A fork of Audacity 4 maintained by Steady Acre Studios for producing the *Desert Road Trips with GregX* Mixcloud show. Changes here are driven by that workflow, not by a general-purpose product roadmap.

## AI-assisted development

Modifications to this fork are written with help from AI coding tools. The history is a working record for the show’s production needs.

## No upstream pull requests (for now)

Pull requests are unlikely to be submitted upstream. Comfort with the Audacity 4 codebase is not yet at a level where defending or justifying those changes in review would be fair to maintainers. Prefer spending time on a private fork over consuming other people’s review bandwidth.

## Patches alongside upstream

DRT changes are also published as patches that sit next to the upstream source. Anyone can download them, apply them to Audacity, and maintain the result themselves. That keeps the modifications available in ordinary source form without depending on this fork or on upstream accepting the work.

## Fedora 44 first

All development and packaging happens on Fedora 44 (until 45 is generally available). Artifacts are built in that environment; they may or may not run cleanly on other Linux distributions.

## Linux only

There is no plan to port DRT-specific work to Windows or macOS. If a change only makes sense on Linux, that is intentional.

---

# Audacity

[![Coverage](https://s3.us-east-1.amazonaws.com/extensions.musescore.org/test/code_coverage/au_coverage_badge.svg)](https://github.com/audacity/audacity/actions/workflows/au4_check_unit_tests.yml)

[**Audacity**](https://www.audacityteam.org) is an easy-to-use, multi-track audio editor and recorder for Windows, macOS, GNU/Linux and other operating systems. More info can be found on https://www.audacityteam.org

## This repository is currently undergoing major structural change.

We're currently working on Audacity 4, which means an entirely new UI and also refactorings aplenty. As such, the `master` branch is currently not particularly friendly to new contributors. It is still possible to submit patches to Audacity 3.x; make sure you branch off `audacity3` if you choose to do so. Build instructions for 3.x can be found [here](https://github.com/audacity/audacity/blob/release-3.7.0/BUILDING.md); build instructions for Audacity 4 can be found [here](https://github.com/audacity/audacity/blob/master/BUILDING.md).

You can stay updated with our efforts on [YouTube](https://youtube.com/@audacity), [Discord](https://discord.gg/audacity) and [our blog](https://audacityteam.org/blog).

## License

Audacity is open source software licensed GPLv3. Most code files are GPLv2-or-later, with the notable exceptions being `/au3/lib-src` (which contains third party libraries), as well as VST3-related code. Documentation is licensed CC-by 3.0 unless otherwise noted. Details can be found in the [license file](LICENSE.txt).
