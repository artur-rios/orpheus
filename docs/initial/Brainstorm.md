# Brainstorm

Notes for pulling the music half of Alexandria out into something of its own.

## Why

Alexandria does everything — music, films, books, comics, images, bookmarks —
and it needs a Rust core, a database and a session before it will play a song.
I want the part I actually use every day, on its own, with none of that behind
it.

I also want it on my phone. Alexandria is a desktop program and always will be;
the core is linked in-process over FFI and there is no build of it for Android.
So this is a rewrite of the part that matters, not a port.

## What it is

A music player. It reads the audio files already on the machine, names them by
their tags rather than by their file names, and plays them.

- Windows, Linux, Android. Same interface on all three.
- No server, no core, no database, no account, no network. It walks the folders
  I point it at, reads the tags itself, and keeps the result in a file next to
  its own settings.
- It never writes to my music. No tag editing, no renaming, no moving, no
  deleting. Read the files, play the files, that is all.

## What I want from it

- Point it at a folder and have it work out what is in there.
- Browse by artist, by record, by song. Rows or a wall of sleeves.
- Search. It should find things by title, by artist, by record.
- Play a track, a record, everything by one artist, or the whole thing
  shuffled. A queue I can see and jump around in. Repeat.
- Remember where I stopped in a track and offer to pick it up there.
- A bar along the bottom that is always there, and a full player I can open.
- Keep playing on the phone when I switch away from it. This is the thing that
  will annoy me first if it is missing.
- Tell me what I actually listen to. Most played songs, artists, records,
  genres. I have never known this about my own library.
- Light and dark. English and Portuguese.

## What I do not want

- Streaming. Scrobbling. Looking anything up on the internet. Fetching cover
  art. If it needs the network it is not this program.
- Anything that edits my files.
- An account, a sync, a cloud. One person, one machine, one library.
- Complicated. Three places to be, not six.

## Things I am unsure about

- **Album artist.** Half my library has no album-artist tag and the rap records
  credit a different guest on every track. If I group by the performer I get
  twelve artists for one record. I need to work it out across the record
  somehow.
- **Cover art.** Every track on a record carries the same JPEG. Storing it
  twelve times is silly.
- **How to identify a track** when there is no database to mint an id. The path,
  probably — which means moving a file loses whatever I knew about it. I think I
  can live with that if I say so out loud.
- **Statistics need to know a play happened**, and nothing records that today.
  What counts as having played a song? Half of it? All of it?

## How

Flutter, because it is the one toolkit that covers the two desktops and Android
from one source and I already know it from Alexandria. Whatever plays audio has
to cover all three too, without transcoding.

Same layering as Alexandria — domain, data, application, presentation, one
composition root — because it worked, and because it is what makes a test
possible without the real engine.
