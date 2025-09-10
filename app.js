const http = require('http');
const https = require('https');
const express = require('express');
const WebSocket = require('ws');
const path = require('path');
const { Rtcm3Parser } = require('./rtcm3');

const app = express();

// Static frontend
app.use(express.static(path.join(__dirname, 'public')));

// Health check
app.get('/healthz', (_req, res) => {
	res.json({ ok: true });
});

// Simple JSON helper
function sendJson(res, status, obj) {
	res.status(status).setHeader('Content-Type', 'application/json');
	res.end(JSON.stringify(obj));
}

// NTRIP v2 push endpoint: stream request body to caster via HTTP POST
// Usage (client-side): POST /api/push?host=...&port=...&mount=...&user=...&password=...&tls=0|1
app.post('/api/push', (req, res) => {
	const host = (req.query.host || '').toString();
	const port = parseInt((req.query.port || '0').toString(), 10);
	const mount = (req.query.mount || '').toString().replace(/^\//, '');
	const user = (req.query.user || '').toString();
	const password = (req.query.password || '').toString();
	const useTls = (req.query.tls || '0').toString() === '1';

	if (!host || !port || !mount || !user) {
		return sendJson(res, 400, { ok: false, error: 'Missing required parameters' });
	}

	const auth = Buffer.from(`${user}:${password}`) .toString('base64');
	const headers = {
		'Host': host,
		'User-Agent': 'NTRIP-Pusher/1.0',
		'Authorization': `Basic ${auth}`,
		'Ntrip-Version': 'Ntrip/2.0',
		'Content-Type': 'gnss/data',
		'Connection': 'close'
	};

	const requestOptions = {
		host,
		port,
		method: 'POST',
		path: `/${encodeURIComponent(mount)}`,
		headers
	};

	const client = useTls ? https : http;

	let bytesSent = 0;
	const upstreamReq = client.request(requestOptions, (upstreamRes) => {
		// Handshake response; for push mode, caster usually returns 200 and keeps connection open
		if (upstreamRes.statusCode && upstreamRes.statusCode >= 400) {
			upstreamRes.resume();
			res.status(upstreamRes.statusCode).json({ ok: false, status: upstreamRes.statusCode });
			upstreamReq.destroy();
			return;
		}
	});

	upstreamReq.on('error', (err) => {
		if (!res.headersSent) sendJson(res, 502, { ok: false, error: err.message });
	});

	req.on('data', (chunk) => {
		bytesSent += chunk.length;
	});

	req.on('end', () => {
		upstreamReq.end();
	});

	req.on('aborted', () => {
		upstreamReq.destroy();
	});

	upstreamReq.on('close', () => {
		if (!res.writableEnded) sendJson(res, 200, { ok: true, bytesSent });
	});

	// Stream client upload to caster
	req.pipe(upstreamReq);
});

const server = http.createServer(app);

// WebSocket for live monitoring
const wss = new WebSocket.Server({ server, path: '/ws' });

// Track sessions for cleanup
wss.on('connection', (ws) => {
	let abortUpstream = null;
	let parser = null;
	let intervalId = null;
	let bytesReceived = 0;
	let messagesParsed = 0;

	function send(obj) {
		if (ws.readyState === WebSocket.OPEN) {
			ws.send(JSON.stringify(obj));
		}
	}

	ws.on('message', (data) => {
		let msg = null;
		try {
			msg = JSON.parse(data.toString());
		} catch (e) {
			return send({ type: 'error', error: 'Invalid JSON' });
		}

		if (msg && msg.action === 'connect') {
			const host = (msg.host || '').toString();
			const port = parseInt((msg.port || '0').toString(), 10);
			const mount = (msg.mount || '').toString().replace(/^\//, '');
			const user = (msg.user || '').toString();
			const password = (msg.password || '').toString();
			const useTls = !!msg.tls;

			if (!host || !port || !mount || !user) {
				return send({ type: 'error', error: 'Missing host/port/mount/user' });
			}

			// Start NTRIP client GET stream
			const auth = Buffer.from(`${user}:${password}`).toString('base64');
			const headers = {
				'Host': host,
				'User-Agent': 'NTRIP-Monitor/1.0',
				'Authorization': `Basic ${auth}`,
				'Ntrip-Version': 'Ntrip/2.0',
				'Accept': '*/*',
				'Connection': 'close'
			};

			const requestOptions = {
				host,
				port,
				method: 'GET',
				path: `/${encodeURIComponent(mount)}`,
				headers
			};

			const client = useTls ? https : http;

			try {
				const upstreamReq = client.request(requestOptions, (upstreamRes) => {
					if ((upstreamRes.statusCode || 0) >= 400) {
						let errBuf = Buffer.alloc(0);
						upstreamRes.on('data', (c) => { errBuf = Buffer.concat([errBuf, c]); });
						upstreamRes.on('end', () => {
							send({ type: 'error', error: `Upstream error ${upstreamRes.statusCode}: ${errBuf.toString()}` });
						});
						return;
					}

					parser = new Rtcm3Parser();
					parser.on('message', (info) => {
						messagesParsed += 1;
						send({ type: 'rtcm', ...info });
					});
					parser.on('crc_error', (info) => {
						send({ type: 'crc_error', ...info });
					});

					upstreamRes.on('data', (chunk) => {
						bytesReceived += chunk.length;
						parser.write(chunk);
					});
					upstreamRes.on('end', () => {
						send({ type: 'info', message: 'Upstream ended' });
					});
				});

				upstreamReq.on('error', (err) => {
					send({ type: 'error', error: err.message });
				});

				upstreamReq.end();
				abortUpstream = () => {
					try { upstreamReq.destroy(); } catch {}
				};
				send({ type: 'info', message: 'Connecting to caster...' });

				// Send stats every second
				let lastBytes = 0;
				intervalId = setInterval(() => {
					const delta = bytesReceived - lastBytes;
					lastBytes = bytesReceived;
					send({ type: 'stats', bytesTotal: bytesReceived, bitrateBps: delta, messagesParsed });
				}, 1000);
			} catch (e) {
				send({ type: 'error', error: e.message });
			}
		}
	});

	ws.on('close', () => {
		if (intervalId) clearInterval(intervalId);
		if (abortUpstream) abortUpstream();
		parser = null;
	});
});

const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 3000;
server.listen(PORT, () => {
	console.log(`NTRIP v2 monitor running on http://localhost:${PORT}`);
});