#!/usr/bin/env -S deno run --allow-net --allow-read --allow-write=/tmp --allow-run --location=https://archive.org

// import a deno std. minimal webserver capable of static file serving, that's been lightly modified
// to _also_ be able to run JS code (since we need to handle /details/IDENTIFIER urls/paths).
import main from 'https://deno.land/x/file_server_plus/mod.ts'

import { warn } from 'https://av.prod.archive.org/js/util/log.js'
import { exe, esc } from 'https://av.prod.archive.org/js/util/cmd.js'

// the static server will call this if it was about to otherwise 404
// eslint-disable-next-line no-undef
globalThis.finalHandler = async (req) => {
  const headers = new Headers()
  headers.append('content-type', 'text/html')

  try {
    const url = new URL(req.url)

    if (url.pathname === '/copy') {
      // xxx token me
      let txt = ''
      if (req.method === 'POST') {
        // https://medium.com/deno-the-complete-reference/a-beginners-guide-to-streams-in-deno-760d51750763

        const outfi = await Deno.makeTempFile({ dir: '/tmp' })
        const destFile = await Deno.open(outfi, { write: true })
        await req.body?.pipeTo(destFile.writable)

        const clone = await exe(`head -1 ${outfi}`)
        const repo = clone.split('/').pop().replace(/\.git$/i, '')
        const path = url.searchParams.get('path')

        txt = await exe(`head -30 ${outfi}`)
        warn(`xxx export INCOMING=${outfi} REPO=${esc(repo)} FILE=${esc(path)}  &&  /prevu/deploy.sh`)

        Deno.removeSync(outfi)
      }

      return Promise.resolve(new Response(
        txt,
        { status: 200, headers },
      ))
    }
  } catch (error) {
    warn({ error })
    return Promise.resolve(new Response(
      `Server Error: ${error.message}`,
      { status: 500, headers },
    ))
  }

  headers.append('content-type', 'text/html')
  return Promise.resolve(new Response(
    '<center><br><br><br><img src="/img/deno.png"><br><br><br>Not Found</center>',
    { status: 404, headers },
  ))
}

main()
