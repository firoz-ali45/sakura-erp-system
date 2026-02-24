<template>
  <section class="mb-6 rounded-lg border border-amber-300 bg-amber-50 p-4">
    <div class="mb-3 flex items-center justify-between">
      <h3 class="text-sm font-semibold text-amber-900">
        Debug Panel (Development Only): {{ title }}
      </h3>
      <button
        class="rounded border border-amber-400 bg-white px-3 py-1 text-xs font-medium text-amber-900 hover:bg-amber-100"
        @click="reloadAll"
      >
        Reload
      </button>
    </div>

    <div class="grid grid-cols-1 gap-3">
      <div
        v-for="entry in entries"
        :key="entry.name"
        class="rounded border border-amber-200 bg-white p-3"
      >
        <div class="mb-2 flex items-center justify-between">
          <p class="text-xs font-semibold text-gray-800">{{ entry.name }}()</p>
          <button
            class="rounded border border-gray-300 px-2 py-0.5 text-xs text-gray-700 hover:bg-gray-100"
            @click="runOne(entry.name)"
          >
            Refresh
          </button>
        </div>

        <pre class="max-h-64 overflow-auto rounded bg-gray-900 p-3 text-xs text-green-200">{{ pretty(entry.value) }}</pre>
      </div>
    </div>
  </section>
</template>

<script setup>
import { onMounted, ref, computed } from 'vue';

const props = defineProps({
  title: { type: String, default: 'Page Debug' },
  loaders: { type: Object, required: true }
});

const results = ref({});

const entries = computed(() =>
  Object.keys(props.loaders || {}).map((name) => ({
    name,
    value: results.value[name] ?? { status: 'not_loaded' }
  }))
);

function pretty(value) {
  try {
    return JSON.stringify(value, null, 2);
  } catch (error) {
    return JSON.stringify({ error: String(error) }, null, 2);
  }
}

async function runOne(name) {
  const loader = props.loaders?.[name];
  if (typeof loader !== 'function') {
    results.value[name] = { error: 'Loader is not a function' };
    return;
  }
  try {
    const data = await loader();
    results.value[name] = {
      ok: true,
      loadedAt: new Date().toISOString(),
      data
    };
  } catch (error) {
    results.value[name] = {
      ok: false,
      loadedAt: new Date().toISOString(),
      error: error?.message || String(error)
    };
  }
}

async function reloadAll() {
  const names = Object.keys(props.loaders || {});
  for (const name of names) {
    await runOne(name);
  }
}

onMounted(async () => {
  await reloadAll();
});
</script>
