---
title: "Teleprompter Video Has No Sound on iPhone? Check the Original"
headline: "No sound? Check the saved take before you rerecord."
breadcrumb: "Fix a silent recording"
description: "Find where sound disappears in an iPhone teleprompter recording. Check playback, microphone access, the saved original and the exported MP4 separately."
date: "2026-10-23"
intro: "A silent exported video does not tell you whether the microphone failed. You may be listening through a different output, playing a muted copy or opening a file that differs from the saved take. Keep the original and identify which stage needs attention."
takeaways:
  - "Play the saved original before changing settings or recording the whole script again. Check playback volume and output first."
  - "If new recordings fail, compare a short Teleprompter Pal take with an iPhone Camera sample. Check microphone permission and record the actual result."
  - "If the original has speech but the export does not, investigate that copy. Changing microphone permission cannot restore speech that was never captured."
coverImage:
  src: "/images/guides/sound-check-objects-v2-cover-1000.webp"
  alt: "Unbranded phone beside a microphone and headphones on a dark desk."
  width: 1600
  height: 901
  mobileSrc: "/images/guides/sound-check-objects-v2-cover-mobile.webp"
  sources:
    - { src: "/images/guides/sound-check-objects-v2-cover-640.webp", width: 640 }
    - { src: "/images/guides/sound-check-objects-v2-cover-1000.webp", width: 1000 }
    - { src: "/images/guides/sound-check-objects-v2-cover-1600.webp", width: 1600 }
thumbnail:
  src: "/images/guides/sound-check-objects-v2-thumbnail.webp"
  width: 640
  height: 361
shareImage:
  src: "/images/guides/sound-check-objects-v2-social.png"
  alt: "Unbranded phone beside a microphone and headphones on a dark desk."
  width: 1200
  height: 630
author:
  name: "Teleprompter Pal team"
  url: "https://teleprompterpal.com/about/"
topics: ["iphone-workflow", "recording-audio"]
contents: true
relatedGuides: ["record-long-script-iphone"]
draft: false
---

## Rule out playback before changing the recording setup

Open the saved take in Teleprompter Pal’s Videos library and play the part where you spoke. If the player shows a mute control, check it. While the video plays, raise media volume to a comfortable level. Apple distinguishes [media volume from ringer and alert volume](https://support.apple.com/guide/iphone/adjust-the-volume-iphb71f9b54d/ios), so a loud ringtone does not settle this check.

Check where you are listening. Headphones or another audio device may be the playback destination. Use the playback-destination control in Control Center to choose the output you intend; Apple explains [changing the audio destination](https://support.apple.com/en-gb/guide/iphone/iph315e0d58d/ios). Then play another clip whose speech you know is audible.

If both clips are silent through that output, investigate playback first. If the known-good clip is audible but your take is not, continue below. Keep that listening setup consistent while comparing files.

## Use the first failing stage to choose the next check

This is a decision aid, not a diagnosis of your phone. “Audible” means you listened to the spoken passage, not simply that a file opened or a timer moved.

<table tabindex="0" aria-label="Silent recording checks and what to investigate next">
<thead><tr><th scope="col">What you find</th><th scope="col">What to check next</th></tr></thead>
<tbody>
<tr><th scope="row">Known-good clips are silent too</th><td>Player mute, media volume and playback destination.</td></tr>
<tr><th scope="row">Camera and Teleprompter Pal samples both lack speech</th><td>Phone microphone checks, obstructions and the connected recording setup.</td></tr>
<tr><th scope="row">Camera has speech; the new Teleprompter Pal original does not</th><td>App permission, reported microphone route and support details. Camera passing does not prove every app or accessory path works.</td></tr>
<tr><th scope="row">Original has speech; exported copy does not</th><td>The selected take, edit range, exported file and destination player.</td></tr>
</tbody>
</table>

## Check permission and compare short new recordings

On iPhone, open **Settings → Privacy & Security → Microphone** and check microphone access for your installed copy of Teleprompter Pal. Apple’s [microphone troubleshooting instructions](https://support.apple.com/en-us/101600) recommend this per-app check. If the app is absent or already has permission, that page directs you to the developer.

Teleprompter Pal’s current capture workflow requires both camera and microphone permission. Denied microphone access blocks camera readiness; it is not a setting for intentionally recording a silent video. If the app displays its camera-information alert, **Open Settings** and **Retry Camera** are the relevant actions. **Rehearse** lets you work on delivery without making a camera recording.

After checking access, record a short sample in the iPhone Camera app and another in Teleprompter Pal. Use the same sentence, distance and quiet location. Stop and replay each saved sample. For example:

> This is my sound check. I will listen to the beginning, this sentence and the final word: finished.

Apple also recommends Voice Memos and recordings with both Camera views when investigating microphone trouble. Remove anything covering the microphone openings and follow its guidance if those recordings are unclear too. A passing Camera sample narrows the problem; it does not certify every third-party recording path.

Before another Teleprompter Pal take, open the camera-settings control with the **FHD** badge. Its Audio section reports **Microphone: …**. Note what it says. This is route information, not a microphone selector or proof that your speech was captured.

If you use an external microphone, compare a short sample with it disconnected, then test the intended setup again before filming. Check the accessory’s own connection instructions rather than assuming every microphone or adapter is supported. Stop before changing connections. Teleprompter Pal handles changed microphone inputs and audio interruptions by stopping capture; check the saved take and recording state before continuing.

## If only the exported MP4 is silent

Return to the original take and listen again. Confirm you exported that take and selected a range containing speech. Follow the [trim, crop and MP4 export walkthrough](/guides/record-video-with-script-iphone/#trim-crop-and-export-a-separate-mp4), then open the newly saved copy in its destination.

Compare the same spoken passage in the original and exported file through the same listening output. If possible, open the exported file in another player. When only one destination is silent, report that distinction rather than treating it as a proven microphone failure.

Do not overwrite or delete the usable original while investigating. An export completing successfully does not replace listening to the result.

## Keep a comparison log before contacting support

Fill in this original worksheet with what you actually hear. Mark each sample audible, silent, no saved take or not tested. This is a suggested procedure, not a completed device test:

```text
iPhone model / iOS:
Teleprompter Pal version:
Microphone or accessory:
Reported Microphone route:
Playback output:
Known-good clip:
Camera sample:
Teleprompter Pal original:
Exported copy / player:
Alert or interruption:
```

If only Teleprompter Pal fails, [contact Teleprompter Pal support](/support/) with these observations. Describe the first failing stage and preserve the take; avoid reinstalling as a first troubleshooting step when local recordings matter.

If speech was never captured, a later permission change or another export cannot recreate that performance. Record the missing passage again, or deliberately create replacement narration in an editor that supports it. For a long video, the [separate-take workflow](/guides/record-long-script-iphone/#record-and-review-one-complete-section) can help you redo only an affected section.

Recording and playback checks in Teleprompter Pal are free. Pro is required for MP4 export; upgrading is not an audio repair. [Check the Free and Pro plan details](/pricing/) when you have a working take to deliver.
