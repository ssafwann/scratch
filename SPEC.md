# Scratch product specification

## Principles

- An unfocused note should look like a physical sticky note. A focused note shows tabs, a toolbar, and contextual controls.
- Keep the feature set small. Ask before adding features, settings, or dependencies outside this specification.

## Window and navigation

- One AppKit `NSPanel` owns the frame, window level, Spaces behavior, and key state. SwiftUI renders the contents.
- Remember the window position and size. Pin the note above other windows by default.
- Six lists exist from first launch, all named Untitled. Each list has an automatically assigned color. Click the title to rename the list. Cmd+1–6 switches lists.
- Left-align the title. Show the uncompleted count at the right when unfocused.
- When focused, show the toolbar above the title row and right-align the tab dots on the title row. Hovering over a dot previews that list's name in the title.
- The toolbar has pin, close, light/dark, completed filter, clear completed, and collapse controls. Pin and close stay visible in the toolbar. Cmd+W closes the app.
- The completed filter menu offers Hide completed and Move completed to bottom. Show the wand-sparkles clear control only when the list has completed tasks.
- Collapse the note to a single bar showing the list name and a pill with the uncompleted count.

## Tasks

- The focused footer has an “Add task…” input, the note background, and a subtle top separator.
- Tasks have square checkboxes. Completed tasks use strikethrough. Click task text to edit. Shift+Enter inserts a newline.
- Support inline Markdown in tasks for **bold**, *italic*, `code`, ~~strikethrough~~, and [links](https://example.com). Bold marks an important task.
- In a focused note, hovering over a task reveals a filled X on the right. Reserve its space to prevent layout shifts. Deletion is immediate and permanent.
- Allow one level of subtasks in v1. Show an inline “Add subtask” row only while editing a task. Its filled plus matches the subtask checkbox size and has no hover background. Keep basic creation in this inline row.
- Completing a parent completes all its subtasks. Deleting a parent removes all its subtasks, including when clear completed deletes that parent.
- Drag to reorder tasks with their subtasks or move a subtask to another parent. Drop onto a list's tab dot to move the task to that list.
- Use a 4-point note-tinted scrollbar thumb with a transparent track. Show it while scrolling or hovering. Hide contextual controls when the note loses focus.

## Implementation

- Swift and SwiftUI, macOS 14+, universal binary.
- SQLite via GRDB. Store tasks in a flat table with `position` and `indentLevel`.
- Use KeyboardShortcuts and support launch at login via `SMAppService`.
- Use Lucide SVGs as template images in the asset catalog, with one standard icon size and a 1.5 stroke width.
- Keep v1 to to-dos, with no images, sync, undo, or auto-update.

## Milestones

1. Panel spike
2. Data layer
3. Core list
4. Tabs
5. Toolbar
6. Nesting and drag and drop
7. Release
