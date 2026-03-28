function uint8ArrayToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

function base64ToUint8Array(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

export function generateSalt(): Uint8Array {
  return window.crypto.getRandomValues(new Uint8Array(16));
}

export async function deriveKey(
  password: string,
  salt: Uint8Array,
): Promise<CryptoKey> {
  const encoder = new TextEncoder();
  const keyMaterial = await window.crypto.subtle.importKey(
    'raw',
    encoder.encode(password),
    'PBKDF2',
    false,
    ['deriveKey'],
  );

  return window.crypto.subtle.deriveKey(
    {
      name: 'PBKDF2',
      salt: salt as BufferSource,
      iterations: 600_000,
      hash: 'SHA-256',
    },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt'],
  );
}

export interface EncryptedPayload {
  encryptedContent: string;
  iv: string;
  authTag: string;
  pbkdf2Salt: string;
}

export async function encrypt(
  plaintext: string,
  password: string,
): Promise<EncryptedPayload> {
  const salt = generateSalt();
  const key = await deriveKey(password, salt);
  const iv = window.crypto.getRandomValues(new Uint8Array(12));
  const encoder = new TextEncoder();

  const ciphertextWithTag = await window.crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    encoder.encode(plaintext),
  );

  const rawBytes = new Uint8Array(ciphertextWithTag);
  const ciphertext = rawBytes.slice(0, rawBytes.byteLength - 16);
  const authTag = rawBytes.slice(rawBytes.byteLength - 16);

  return {
    encryptedContent: uint8ArrayToBase64(ciphertext),
    iv: uint8ArrayToBase64(iv),
    authTag: uint8ArrayToBase64(authTag),
    pbkdf2Salt: uint8ArrayToBase64(salt),
  };
}

export async function decrypt(
  encryptedContent: string,
  iv: string,
  authTag: string,
  pbkdf2Salt: string,
  password: string,
): Promise<string> {
  const salt = base64ToUint8Array(pbkdf2Salt);
  const key = await deriveKey(password, salt);
  const ivBytes = base64ToUint8Array(iv);
  const ciphertext = base64ToUint8Array(encryptedContent);
  const authTagBytes = base64ToUint8Array(authTag);

  const combined = new Uint8Array(ciphertext.byteLength + authTagBytes.byteLength);
  combined.set(ciphertext, 0);
  combined.set(authTagBytes, ciphertext.byteLength);

  const decrypted = await window.crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: ivBytes as BufferSource },
    key,
    combined,
  );

  const decoder = new TextDecoder();
  return decoder.decode(decrypted);
}
