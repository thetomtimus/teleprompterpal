# Teleprompter Pal

One repository for the Mac app, the iPhone app, shared Swift packages, and the website. The apps have separate Xcode targets and release independently.

| Component | Source | Build target |
| --- | --- | --- |
| Mac app (Private Presenter) | [`PrivatePresenterApp/`](PrivatePresenterApp/) | `PrivatePresenter` |
| iPhone app (Teleprompter Pal) | [`iPhoneApp/`](iPhoneApp/) | `TeleprompterPhone` |
| Shared prompting and Mac core | [`Packages/TeleprompterCore/`](Packages/TeleprompterCore/) | Swift packages `PromptingCore` and `TeleprompterCore` |
| iPhone script library | [`Packages/PhoneLibrary/`](Packages/PhoneLibrary/) | Swift package `PhoneLibrary` |
| iPhone capture, export and storage | [`iPhonePrototype/`](iPhonePrototype/) | Shared services and `PrototypeSupport` package |
| Astro marketing website | [`Marketing/`](Marketing/) | `npm run build` |
| Privacy and support pages | [`Website/`](Website/) | `python3 Website/build.py` |

## Native apps

The Mac app targets macOS 14 or later. The iPhone app targets iOS 18 or later. Use Xcode with Swift 6 support and XcodeGen 2.45.4 or later. The current source was built using Xcode 27.0.

Generate the shared Xcode project:

```sh
xcodegen generate --spec project.yml
open PrivatePresenter.xcodeproj
```

Select **PrivatePresenter** for Mac or **TeleprompterPhone** for iPhone. The iPhone target also compiles capture/export services from `iPhonePrototype/App/`; that folder is part of the main app's source dependency, not a separately required installation. See the [iPhone guide](iPhoneApp/README.md) for its script, recording, editing and delivery workflows. The [prototype guide](iPhonePrototype/README.md) covers the separate technical harness.

Package and boundary checks run without installing an app:

```sh
python3 Scripts/test_iphone_structure.py
swift test --package-path Packages/TeleprompterCore
swift test --package-path Packages/PhoneLibrary
swift test --package-path iPhonePrototype/Support
```

The app's native host and UI tests are in `iPhoneAppTests/`, `iPhoneUITests/`, `PrivatePresenterAppTests/`, and `PrivatePresenterUITests/`. Simulator/device scripts under `Scripts/` document their required destinations. Signing credentials, distribution archives, personal recordings, and local device-validation captures are excluded from source commits.

## Website

Use Node 22.22 or later:

```sh
cd Marketing
npm ci
npm run dev
```

`npm run build` checks the Astro source and produces `Marketing/dist/`. See the [website guide](Marketing/README.md) for the reference design system and shared CTA/QR destination. Committing the source does not deploy the website or publish an app release.

## App assets

The shipping iPhone icon and fictional onboarding presenter are in `iPhoneApp/Assets.xcassets/`. The approved icon master, selection record and original asset prompts are retained in `.impeccable/assets/`. Generated projects, package caches and build output stay local. Dated device/test evidence linked by older guides is retained locally and is not required to build either app.
