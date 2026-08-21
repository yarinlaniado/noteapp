import os
from app import app


class PrefixMiddleware:
    """Makes Flask aware it's served under a path prefix on the shared ALB.

    The ALB forwards paths verbatim (e.g. /env/<ns>/read/<id>) — it does not
    rewrite them. This strips the prefix before Flask routes the request and
    sets SCRIPT_NAME so url_for() adds it back when generating links. main
    runs with an empty prefix, so this is a no-op there.
    """

    def __init__(self, wsgi_app, prefix=''):
        self.wsgi_app = wsgi_app
        self.prefix = prefix.rstrip('/')

    def __call__(self, environ, start_response):
        if self.prefix and environ.get('PATH_INFO', '').startswith(self.prefix):
            environ['SCRIPT_NAME'] = self.prefix
            environ['PATH_INFO'] = environ['PATH_INFO'][len(self.prefix):]
        return self.wsgi_app(environ, start_response)


app.wsgi_app = PrefixMiddleware(app.wsgi_app, prefix=os.environ.get('SCRIPT_NAME', ''))

if __name__ == "__main__":
   app.run(host="0.0.0.0", port=8000)
