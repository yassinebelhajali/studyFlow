const { createClient } = require('@supabase/supabase-js');

const { loadEnvFiles } = require('../src/config/env');

loadEnvFiles();

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const email = String(args.email || '').trim().toLowerCase();
  const password = String(args.password || '');
  const confirmEmail = toBoolean(args.confirmEmail, true);
  const createIfMissing = toBoolean(args.createIfMissing, false);

  if (!email || !password) {
    printUsageAndExit();
    return;
  }

  if (password.length < 6) {
    throw new Error('Password must be at least 6 characters');
  }

  const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey =
    process.env.SUPABASE_SERVICE_ROLE_KEY ||
    process.env.SUPABASE_SECRET_KEY ||
    '';

  if (!supabaseUrl) {
    throw new Error('SUPABASE_URL is required in backend/.env.local');
  }
  if (!serviceRoleKey) {
    throw new Error('SUPABASE_SERVICE_ROLE_KEY is required in backend/.env.local');
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });

  const user = await findUserByEmail(admin, email);
  let targetUser = user;
  if (!targetUser && createIfMissing) {
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: confirmEmail,
    });
    if (error) {
      throw new Error(error.message || 'Failed to create auth user');
    }
    targetUser = data.user || null;
  }

  if (!targetUser) {
    throw new Error(
      `No auth user found for email: ${email}. Re-run with --create-if-missing true to create one.`,
    );
  }

  const updatePayload = {
    password,
    email_confirm: confirmEmail,
  };

  const { error } = await admin.auth.admin.updateUserById(
    targetUser.id,
    updatePayload,
  );
  if (error) {
    throw new Error(error.message || 'Failed to update user password');
  }

  console.log(
    JSON.stringify(
      {
        success: true,
        userId: targetUser.id,
        email,
        emailConfirmed: confirmEmail,
        created: !user && createIfMissing,
      },
      null,
      2,
    ),
  );
}

async function findUserByEmail(admin, email) {
  const perPage = 200;
  let page = 1;

  while (true) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage });
    if (error) {
      throw new Error(error.message || 'Failed to list users');
    }

    const users = data?.users || [];
    const found = users.find(
      (user) => String(user.email || '').trim().toLowerCase() === email,
    );
    if (found) {
      return found;
    }

    if (users.length < perPage) {
      return null;
    }

    page += 1;
  }
}

function parseArgs(argv) {
  const parsed = {};

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) {
      continue;
    }

    const key = token.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      parsed[key] = true;
      continue;
    }

    parsed[key] = next;
    i += 1;
  }

  return {
    email: parsed.email,
    password: parsed.password,
    confirmEmail: parsed['confirm-email'],
    createIfMissing: parsed['create-if-missing'],
  };
}

function toBoolean(value, fallback) {
  if (typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true' || normalized === '1' || normalized === 'yes') {
      return true;
    }
    if (normalized === 'false' || normalized === '0' || normalized === 'no') {
      return false;
    }
  }

  return fallback;
}

function printUsageAndExit() {
  console.error(
    'Usage: node scripts/set_supabase_password.js --email <email> --password <password> [--confirm-email true|false] [--create-if-missing true|false]',
  );
  process.exitCode = 1;
}

main().catch((error) => {
  console.error(error.message || String(error));
  process.exit(1);
});
