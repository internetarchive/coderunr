#!/usr/bin/env -S deno run --allow-net --allow-read --allow-write=/tmp --allow-run --location=https://archive.org

// import a deno std. minimal webserver capable of static file serving, that's been lightly modified
// to _also_ be able to run JS code.
import httpd from 'https://deno.land/x/httpd/mod.js'

import { warn } from 'https://av.prod.archive.org/js/util/log.js'
import { exe, esc } from 'https://av.prod.archive.org/js/util/cmd.js'

// eslint-disable-next-line consistent-return
httpd((req, headers) => {
  const url = new URL(req.url)

  if (url.pathname === '/copy') {
    // xxx token me
    if (req.method === 'POST') {
      const FILE = url.searchParams.get('FILE')
      const CLONE = url.searchParams.get('CLONE')
      const BRANCH = url.searchParams.get('BRANCH')

      // https://medium.com/deno-the-complete-reference/a-beginners-guide-to-streams-in-deno-760d51750763

      const outfi = Deno.makeTempFileSync({ dir: '/tmp' })
      const destFile = Deno.openSync(outfi, { write: true })
      req.body?.pipeTo(destFile.writable)
        .then(() => {
          // xxx exe() once token gated
          warn(`INCOMING=${outfi} FILE=${esc(FILE)} CLONE=${esc(CLONE)} BRANCH=${esc(BRANCH)}  /coderunr/run.sh`)
          return exe(`head -30 ${outfi}`)
        }).then((txt) => {
          Deno.removeSync(outfi)
          return new Response(txt, { headers })
        })
    }

    return new Response('', { headers })
  }
}, { cors: false })
