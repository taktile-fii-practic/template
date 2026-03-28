import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { PasswordPrompt } from '../components/PasswordPrompt';
import { SecretReveal } from '../components/SecretReveal';
import { viewSecret, ApiError } from '../api/client';
import { decrypt } from '../services/crypto';

type ViewState = 'password' | 'reveal' | 'destroyed' | 'error';

export function ViewPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [state, setState] = useState<ViewState>('password');
  const [secret, setSecret] = useState('');
  const [error, setError] = useState('');

  const handlePassword = async (password: string) => {
    if (!id) return;
    setError('');
    try {
      const data = await viewSecret(id, password);
      const plaintext = await decrypt(
        data.encryptedContent,
        data.iv,
        data.authTag,
        data.pbkdf2Salt,
        password,
      );
      setSecret(plaintext);
      setState('reveal');

      // Show destroyed state after a delay
      setTimeout(() => setState('destroyed'), 30000);
    } catch (err) {
      if (err instanceof ApiError) {
        if (err.status === 401) {
          setError('Wrong password. Try again.');
          return;
        }
        if (err.status === 404) {
          navigate('/not-found', { replace: true });
          return;
        }
      }
      setError(err instanceof Error ? err.message : 'Failed to decrypt');
    }
  };

  if (state === 'reveal' || state === 'destroyed') {
    return <SecretReveal secret={secret} destroyed={state === 'destroyed'} />;
  }

  return <PasswordPrompt onSubmit={handlePassword} error={error} />;
}
