const { PassThrough } = require('node:stream');
const http = require('node:http');
const jwt = require('jsonwebtoken');

function makeToken(user) {
  return jwt.sign(
    user,
    process.env.JWT_ACCESS_SECRET || 'test_secret_key_asuhkita',
    { expiresIn: '1h' }
  );
}

function requestApp(app, { method = 'GET', path = '/', headers = {}, body = null } = {}) {
  return new Promise((resolve, reject) => {
    const socket = new PassThrough();
    socket.remoteAddress = '127.0.0.1';
    const req = new http.IncomingMessage(socket);
    req.method = method;
    req.url = path;
    req.headers = {
      host: 'localhost',
      ...Object.fromEntries(
        Object.entries(headers).map(([k, v]) => [k.toLowerCase(), v])
      ),
    };

    if (body !== null && body !== undefined) {
      const payload = typeof body === 'string' ? body : JSON.stringify(body);
      req.headers['content-type'] = req.headers['content-type'] || 'application/json';
      req.headers['content-length'] = String(Buffer.byteLength(payload));
      req.push(payload);
    }
    req.push(null);

    const res = new http.ServerResponse(req);
    const chunks = [];
    res.write = (chunk) => {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
      return true;
    };
    res.end = (chunk) => {
      if (chunk) chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
      const raw = Buffer.concat(chunks).toString('utf8');
      let parsed = null;
      try {
        parsed = raw ? JSON.parse(raw) : null;
      } catch (_) {
        parsed = raw;
      }
      resolve({ status: res.statusCode, headers: res.getHeaders(), body: parsed });
      return res;
    };

    app.handle(req, res, (err) => {
      if (err) reject(err);
    });
  });
}

module.exports = { makeToken, requestApp };
