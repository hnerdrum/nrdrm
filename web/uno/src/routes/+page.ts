import { PUBLIC_SERVER_URL } from '$env/static/public';

export async function load({ fetch }) {
	const res = await fetch(`${PUBLIC_SERVER_URL}/games`, {
		headers: {
			'Content-Type': 'application/json'
		},
		credentials: 'include'
	});
	const games = await res.json();
	return {
		games
	};
}
