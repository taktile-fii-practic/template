export interface Secret {
  id: string;
  encryptedBlob: string;
  passwordHash: string;
  email: string;
  ttl: number;
  createdAt: string;
  viewed: boolean;
}

export interface CreateSecretRequest {
  encryptedContent: string;
  iv: string;
  authTag: string;
  pbkdf2Salt: string;
  password: string;
  email: string;
  expiresIn: '1h' | '24h' | '7d';
}

export interface CreateSecretResponse {
  id: string;
  expiresAt: string;
}

export interface ViewSecretRequest {
  password: string;
}

export interface ViewSecretResponse {
  encryptedContent: string;
  iv: string;
  authTag: string;
  pbkdf2Salt: string;
}

export interface GenerateRequest {
  prompt: string;
}

export interface GenerateResponse {
  content: string;
}

export interface DeleteMessage {
  secretId: string;
  email: string;
}

export interface NotificationEvent {
  email: string;
  event: 'viewed' | 'expired';
  secretId: string;
  timestamp: string;
}
