import { warn } from 'https://av.prod.archive.org/js/util/log.js'


// https://developer.chrome.com/articles/file-system-access/

// xxx File System Change Observer:
// https://docs.google.com/document/d/1jYXOZGen4z7kNrKnwBk5z4tbGRmGXmQ9nmoyJRm-V9M/edit#heading=h.7nki9mck5t64

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

      if (path.match(/\.git/))
        warn({ path })

      if (githead && branch === null)
        branch = (await file.text()).split('/').pop()
      else if (!clone && path.match(/\.git\/config$/))
        clone = ((await file.text()).match(/^\s*url\s*=\s*([\S]+)/) ?? ['']).pop()

      if (prev && (!(path in prev) || prev[path] !== file.lastModified)) {
        warn(`${path} changed`)
        if (githead)
          warn(`branch now: ${branch}`)
      }
      next[path] = file.lastModified
    } else if (handle.kind === 'directory') {
      const subdir = `${cwd}${handle.name}/`
      warn(`dir: ${subdir}`)
      await scandir(subdir, handle)
    }
  }

  if (cwd === '') {
    // we finished a scan of the top dir
    // warn({ next })
    warn({ clone, branch })
    prev = next
    next = {}

    if (!rescanner) {
      rescanner = setInterval(scandir, 5000)// Check files every 5 seconds
    }
  }
}
