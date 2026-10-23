// English is the source of truth. Every rendered string is checked by localize.mjs.
/** @typedef {{image: string, caption: string, video?: string, width?: number, height?: number}} HelpMedia */
/** @type {Array<{slug: string, group: string, title: string, description: string, image?: string, caption?: string, sections: Array<{id: string, title: string, steps?: string[], paragraphs?: string[], media?: HelpMedia}>}>} */
export const helpArticles = [
  {
    slug: 'create-a-script', group: 'Scripts', title: 'Create a script',
    description: 'Write or paste your words, name your script, and check that it is saved on your iPhone.',
    sections: [
      { id: 'write', title: 'Write your first script', steps: [
        'Open Scripts and tap the plus tile to create a script.',
        'Tap the title to name it, then type or paste your words into the editor.',
        'Check the saved status before leaving the editor. Changes save automatically on this iPhone.',
      ] },
      { id: 'next', title: 'Rehearse before recording', paragraphs: [
        'Open the three-dot Script actions menu and choose Rehearse. You can practice without allowing camera or microphone access.',
        'The red Record button in the editor opens Camera mode. It does not start a recording until you tap Record again in the studio.',
      ] },
      { id: 'storage', title: 'Where your words are stored', paragraphs: [
        'Scripts and original recordings stay on this iPhone. No account is required. Keep a separate copy of important script text before replacing your phone or deleting the app.',
      ] },
    ],
  },
  {
    slug: 'import-and-manage-scripts', group: 'Scripts', title: 'Import and manage scripts',
    description: 'Import a plain-text file, find a script, duplicate a draft, or restore a deleted script.',
    sections: [
      { id: 'import', title: 'Import a text file', steps: [
        'In Scripts, open the Edit menu and choose Import Text.',
      ] },
      { id: 'choose-file', title: 'Choose and check the text file', steps: [
        'Choose a plain-text (.txt) file in the iPhone file picker.',
        'Open the imported script and check its title, paragraph breaks, and saved status.',
      ], paragraphs: ['PDF and Word documents are not imported directly. Copy their text into a script, or save a plain-text version first.'] },
      { id: 'organize', title: 'Find or duplicate a script', paragraphs: [
        'Choose Search Scripts in the Edit menu to find a script. Touch and hold a script tile, then choose Duplicate to keep a separate draft.',
      ] },
      { id: 'restore', title: 'Recover a deleted script', paragraphs: [
        'Deleting a script moves it to Recently Deleted. Open that section from the Edit menu and restore the script you want to keep. Permanently deleting it there cannot be undone.',
      ] },
    ],
  },
  {
    slug: 'rehearse-and-scroll', group: 'Read and record', title: 'Rehearse and adjust scrolling',
    description: 'Set a comfortable text size and pace, pause the reader, and return to your place.',
    sections: [
      { id: 'practice', title: 'Start a rehearsal', steps: [
        'Open your script, open the three-dot Script actions menu, and choose Rehearse.',
        'Tap Play text to start scrolling. Tap Pause text or drag the text to stop and find your place.',
        'Use Restart when you want to begin from the top.',
      ] },
      { id: 'adjust', title: 'Make the text comfortable', paragraphs: [
        'Use the Pace and Font sliders below the rehearsal reader to adjust scrolling speed and text size. In Camera mode, Size, Background, and Speed adjust the reading panel.',
        'Read a few sentences aloud and adjust the speed to match your delivery. Scrolling follows the speed you set; it does not follow your voice.',
      ] },
      { id: 'position', title: 'Resume from your place', paragraphs: [
        'The reader remembers your place for that script. Check the starting line when you return, especially after editing the text.',
      ] },
    ],
  },
  {
    slug: 'record-a-video', group: 'Read and record', title: 'Record a video',
    description: 'Open Camera mode, check your framing and permissions, and record a take with your script.',
    sections: [
      { id: 'prepare', title: 'Prepare the camera', steps: [
        'Open a script with some text and tap the red Record button. From the library, the Record button asks you to choose a script first.',
        'Allow camera and microphone access when prompted. Check the camera preview, choose the front or rear camera, and set your text size and pace.',
        'Choose portrait or landscape before starting. The recording orientation stays fixed for that take.',
      ] },
      { id: 'record', title: 'Start and stop your take', paragraphs: [
        'This demonstration runs the real app in an iPhone simulator. The camera preview is blank and the take is simulated; on your iPhone, the preview shows your camera image.',
        'Tap Record inside the studio to start the countdown. Tap Stop when you finish, then allow the app to finish saving.',
        'Keep the app visible during recording. Calls, interruptions, or low storage can end a take. There is no fixed recording time limit, but available storage matters.',
      ] },
      { id: 'review', title: 'Check the recording', paragraphs: [
        'Open Videos to find recordings grouped by script. Tap a thumbnail to play the original and check the picture and sound before editing or sharing.',
      ] },
    ],
  },
  {
    slug: 'trim-and-crop', group: 'Edit and export', title: 'Trim and crop a recording',
    description: 'Shorten a take and adjust its frame while keeping the original recording.',
    sections: [
      { id: 'trim', title: 'Choose the part to keep', steps: [
        'Open Videos, play a recording, and choose Edit Video.',
        'Drag the start and end handles on the timeline to shorten the selection.',
        'Use Play selection to check the cut. Reset restores the full time range.',
      ] },
      { id: 'crop', title: 'Adjust the frame', paragraphs: [
        'Open Crop and choose a frame shape. Move the frame or use Horizontal position and Vertical position to keep the subject inside it. Choose Custom to adjust the crop corners, then tap Done to apply it.',
      ] },
      { id: 'save', title: 'Save the edit', paragraphs: [
        'Tap Done to save your edit. The original recording remains in the library, so trimming and cropping do not replace it.',
        'Export MP4 prepares a separate video using the saved trim and crop. If you have unsaved changes, the button reads Save Edit & Export MP4. Export requires Pro.',
      ] },
    ],
  },
  {
    slug: 'export-and-share', group: 'Edit and export', title: 'Export and share a video',
    description: 'Prepare an MP4 copy and save it to Photos or Files, or send it through the iPhone share sheet.',
    sections: [
      { id: 'prepare', title: 'Prepare an MP4', steps: [
        'Open your recording in Edit Video and check the trim and crop.',
        'Tap Export MP4, or Save Edit & Export MP4 if you have changed the edit. Pro is required for export.',
        'Keep the app open while it prepares the file. When MP4 ready appears, use Play MP4 to check the result.',
      ] },
      { id: 'destination', title: 'Save or share the file', paragraphs: [
        'Save to Photos adds the video to your photo library and asks for permission if needed. Save to Files lets you choose a folder. Share opens the iPhone share sheet.',
        'Scroll down if a destination is below the video preview. MP4 ready means the copy is in temporary storage; finish a save or share action to deliver it outside the app.',
      ] },
      { id: 'confirm', title: 'Confirm that your video was saved', paragraphs: [
        'Wait for Saved to Photos or Saved to Files, then open that destination and play the video. The original recording remains in Teleprompter Pal.',
      ] },
      { id: 'retry', title: 'If export is interrupted', paragraphs: [
        'Your original recording and saved edit are kept if export stops. Return to the export screen and choose Retry Export.',
        'If a save or share result is uncertain, check Photos, Files, or the receiving app before trying again to avoid duplicate copies.',
      ] },
    ],
  },
  {
    slug: 'plans-and-billing', group: 'Help and settings', title: 'Plans and billing',
    description: 'Understand free features, Pro export, restoring purchases, and managing an Apple subscription.',
    sections: [
      { id: 'included', title: 'What you can do for free', paragraphs: [
        'Create scripts, rehearse, record, and trim or crop recordings for free. Pro unlocks MP4 export and saving or sharing the exported video.',
      ] },
      { id: 'plans', title: 'Choose a plan', paragraphs: [
        'Weekly, monthly, and annual plans are available. The annual plan includes a three-day trial for eligible subscribers. Weekly and monthly plans do not include a trial.',
        'Check the pricing page and the Apple purchase sheet for the price and renewal terms that apply to you before subscribing.',
      ] },
      { id: 'restore', title: 'Restore or manage a subscription', paragraphs: [
        'Open Settings & Help, then Subscription. Use Restore Purchases if you have an active purchase on the same Apple Account but Pro is not showing.',
        'Manage or cancel an Apple subscription in iPhone Settings under your name, then Subscriptions. Deleting the app does not cancel a subscription.',
      ] },
    ],
  },
  {
    slug: 'troubleshooting', group: 'Help and settings', title: 'Troubleshooting',
    description: 'Resolve camera permissions, interrupted takes, missing scripts, and export problems.',
    sections: [
      { id: 'camera', title: 'The camera or Record button is unavailable', paragraphs: [
        'Check that your script contains text. In Settings & Help, choose Open iPhone Settings and allow camera and microphone access. Return to the app and reopen Camera mode.',
        'Camera recording requires a real iPhone. Rehearsal works without camera or microphone permission.',
      ] },
      { id: 'interruption', title: 'A recording stopped unexpectedly', paragraphs: [
        'Keep Teleprompter Pal in the foreground and check that your iPhone has free storage. Open Videos after an interruption and review any saved take before recording again.',
      ] },
      { id: 'missing', title: 'A script seems to be missing', paragraphs: [
        'Clear the script search, then check Recently Deleted in the Edit menu. Scripts are stored on this iPhone; signing into another device does not sync the library.',
      ] },
      { id: 'export', title: 'An export did not arrive', paragraphs: [
        'MP4 ready is not a confirmation that the file was saved to Photos or Files. Complete a destination action and check that destination. If preparation failed, use Retry Export and keep the app open.',
      ] },
      { id: 'contact', title: 'Ask for help', paragraphs: [
        'Contact support with your iPhone model, iOS version, app version, and the steps that led to the problem. Include the exact error message, but leave out private script text.',
      ] },
    ],
  },
];

// Keep each visual next to the task it demonstrates. The footage and UI captures
// are shared assets; their captions and the surrounding steps are translated.
/** @type {Record<string, Record<string, HelpMedia>>} */
const walkthroughs = {
  'create-a-script': {
    write: { image: '/images/help/editor.webp', caption: 'The script editor shows the title, saved status, and Record button.' },
    next: { image: '/images/help/script-actions.webp', caption: 'Open Script actions to rehearse, duplicate a draft, or change Reader Settings.' },
  },
  'import-and-manage-scripts': {
    import: { image: '/images/help/import-menu.webp', caption: 'Open Edit, then choose Import Text to select a .txt file.' },
    'choose-file': { image: '/images/help/import-picker.webp', caption: 'The iPhone file picker can search for a text file by name. Tap the file to import it.' },
  },
  'rehearse-and-scroll': {
    practice: { image: '/images/help/rehearsal.webp', video: '/images/help/rehearsal.mp4', caption: 'Watch Play text start scrolling, a drag pause the reader, and Restart return to the beginning.' },
    adjust: { image: '/images/help/rehearsal-controls.webp', caption: 'The rehearsal reader has separate Pace and Font sliders. Adjust them before your take.' },
  },
  'record-a-video': {
    prepare: { image: '/images/help/camera.webp', caption: 'Camera mode includes Size, Background, Speed, camera settings, and the front/rear camera control.' },
    record: { image: '/images/help/recording.webp', video: '/images/help/recording.mp4', caption: 'Watch Record start the countdown, the timer appear, and Stop finish the take. Simulator demonstration with a blank camera preview.' },
  },
  'trim-and-crop': {
    trim: { image: '/images/help/trim.webp', video: '/images/help/trim.mp4', caption: 'Drag both timeline handles, then play the selected part. Real sample footage makes the change visible.' },
    crop: { image: '/images/help/crop.webp', video: '/images/help/crop.mp4', caption: 'Choose a square frame, adjust its position, and apply the crop with Done.' },
    save: { image: '/images/help/cropped-video.webp', caption: 'The preview shows your chosen framing. Export creates a separate MP4 and keeps the original.' },
  },
  'export-and-share': {
    prepare: { image: '/images/help/export-ready.webp', caption: 'MP4 ready means the video is prepared. You still need to choose where to save or share it.' },
    destination: { image: '/images/help/destinations.webp', caption: 'Scroll to Save or share to see Save to Photos, Save to Files, and Share.' },
    confirm: { image: '/images/help/photos-saved.webp', caption: 'Saved to Photos confirms delivery to your photo library. Open Photos to check the exported video.' },
  },
};
for (const article of helpArticles) {
  for (const section of article.sections) section.media = walkthroughs[article.slug]?.[section.id];
}

export const helpGroups = [...new Set(helpArticles.map(article => article.group))];
export const helpPath = slug => `/help/${slug}/`;
