import { defineConfig } from 'vitepress';

// https://vitepress.dev/reference/site-config
export default defineConfig(({ mode }) => {
	return {
		title: 'Git Outta Here',
		description: 'Play my GitHub profile',
		base: mode === 'production' ? '/git-outta-here/' : '/',
		outDir: '../build/web',
		ignoreDeadLinks: true,
	};
});
