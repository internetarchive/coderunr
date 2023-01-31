import { warn } from 'https://av.prod.archive.org/js/util/log.js'


// https://developer.chrome.com/articles/file-system-access/

// xxx File System Change Observer ('watch' proposal):
// https://docs.google.com/document/d/1jYXOZGen4z7kNrKnwBk5z4tbGRmGXmQ9nmoyJRm-V9M/edit#heading=h.7nki9mck5t64

const MAX_MESSAGES = 10

let prev
let next = {}
let rescanner
let dirhandle
let clone
let branch = null

// eslint-disable-next-line no-use-before-define
document.getElementById('dir-sel').addEventListener('click', scandir)

async function scandir(cwd = '', dirh = null) {
  if (!dirhandle) {
    // eslint-disable-next-line no-param-reassign
    cwd = ''
    dirhandle = await window.showDirectoryPicker()
  }
  const dirptr = dirh ?? dirhandle

  for await (const handle of dirptr.values()) {
    if (handle.kind === 'file') {
      // warn('handle.name:', handle.name)
      const file = await handle.getFile()
      const path = `${cwd}${file.name}`
      const githead = path.match(/\.git\/HEAD$/)
      const changed = (prev && (!(path in prev) || prev[path] !== file.lastModified))

      if (githead && (branch === null || changed))
        branch = (await file.text()).split('/').pop().trim()
      else if (!clone && path.match(/\.git\/config$/))
        clone = ((await file.text()).match(/^\s*url\s*=\s*([^\s]+)/m) ?? ['']).pop()

      if (changed) {
        // eslint-disable-next-line no-use-before-define
        filechanged(path, file)
        if (githead) {
          document.getElementById('info').innerHTML = `
            clone url: ${clone}<br>
            branch: ${branch}`
        }
      }
      // if `.git/refs/remotes/origin/main changes`, seems like a git push happened
      // if (githead || !path.match(/\.git\//)) // only track .git/HEAD in .git/ folder (for now)
      next[path] = file.lastModified
    } else if (handle.kind === 'directory') {
      const subdir = `${cwd}${handle.name}/`
      // warn(`dir: ${subdir}`)
      await scandir(subdir, handle)
    }
  }

  if (cwd === '') {
    // we finished a scan of the top dir
    // warn({ next })
    if (!prev) {
      document.getElementById('info').innerHTML = `
        clone url: ${clone}<br>
        branch: ${branch}`
    }
    prev = next
    next = {}

    if (!rescanner)
      rescanner = setInterval(scandir, 5000)// Check files every 5 seconds
  }
}

function filechanged(path, file) {
  // eslint-disable-next-line no-use-before-define
  msg(`${path} changed`)

  if (path.startsWith('.git/')) return

  file.text().then((txt) => {
    // warn({ txt })
    fetch(`/copy?FILE=${encodeURIComponent(path)}&CLONE=${encodeURIComponent(clone)}&BRANCH=${encodeURIComponent(branch)}`, {
      method: 'POST',
      headers: new Headers({
        'content-type': 'application/x-www-form-urlencoded',
      }),
      body: txt,
    }).then(async (res) => {
      warn('response from httpd:\n', await res.text())
    })
  })
}

function msg(str) {
  const e = document.getElementById('msgs')
  const lines = e.innerHTML.split(/<br>/)
  e.innerHTML = [str, ...lines.slice(0, MAX_MESSAGES)].join('<br>')
}
