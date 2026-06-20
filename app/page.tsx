export default function Home() {
  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col justify-center px-6 py-12">
      <p className="text-sm font-semibold uppercase tracking-wider text-slate-600">
        SpiritMatch
      </p>
      <h1 className="mt-4 text-4xl font-semibold text-slate-950">Trading board foundation</h1>
      <p className="mt-4 text-lg leading-8 text-slate-700">
        The stage 00 app shell is online. Health checks are available at{" "}
        <code className="rounded bg-white px-1.5 py-1 text-base text-slate-900">/api/health</code>.
      </p>
    </main>
  );
}
