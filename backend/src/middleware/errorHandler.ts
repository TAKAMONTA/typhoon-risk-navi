import type { Context } from 'hono';
import { HTTPException } from 'hono/http-exception';

/**
 * Hono の onError ハンドラ（正しいシグネチャ）。
 * app.onError(errorHandler) で登録する。
 */
export function errorHandler(err: Error, c: Context) {
  console.error('Unhandled error:', err);

  if (err instanceof HTTPException) {
    return c.json(
      {
        success: false,
        error: {
          message: err.message,
          status: err.status,
        },
      },
      err.status
    );
  }

  // Generic internal error
  return c.json(
    {
      success: false,
      error: {
        message: 'Internal Server Error',
        status: 500,
      },
    },
    500
  );
}
