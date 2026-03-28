import { useState } from 'react';
import { AiPrompt } from '../components/AiPrompt';
import { SecretForm } from '../components/SecretForm';
import { LinkDisplay } from '../components/LinkDisplay';
import { TerminalText } from '../components/TerminalText';
import { encrypt } from '../services/crypto';
import { createSecret } from '../api/client';

export function CreatePage() {
  const [aiContent, setAiContent] = useState('');
  const [link, setLink] = useState('');

  const handleSubmit = async (data: {
    content: string;
    password: string;
    email: string;
    expiresIn: '1h' | '24h' | '7d';
  }) => {
    const encrypted = await encrypt(data.content, data.password);
    const result = await createSecret({
      ...encrypted,
      password: data.password,
      email: data.email,
      expiresIn: data.expiresIn,
    });
    setLink(`${window.location.origin}/s/${result.id}`);
  };

  const handleCreateAnother = () => {
    setLink('');
    setAiContent('');
  };

  if (link) {
    return <LinkDisplay link={link} onCreateAnother={handleCreateAnother} />;
  }

  return (
    <div className="create-page">
      <TerminalText text="CREATE A DEAD DROP" as="h1" speed={40} />
      <p className="subtitle">
        Encrypt a secret. Share the link. It self-destructs after one view.
      </p>
      <AiPrompt onGenerated={setAiContent} />
      <SecretForm initialContent={aiContent} onSubmit={handleSubmit} />
    </div>
  );
}
