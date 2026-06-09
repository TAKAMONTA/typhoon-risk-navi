import type { Context } from 'hono';

export interface SuccessResponse<T> {
  success: true;
  data: T;
}

export interface ErrorResponse {
  success: false;
  error: {
    message: string;
    code?: string;
  };
}

export const success = <T>(c: Context, data: T, status = 200) => {
  return c.json<SuccessResponse<T>>({ success: true, data }, status);
};

export const fail = (c: Context, message: string, status = 400, code?: string) => {
  return c.json<ErrorResponse>(
    {
      success: false,
      error: { message, ...(code && { code }) },
    },
    status
  );
};
