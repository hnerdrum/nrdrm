import { actions } from 'astro:actions';

const form = document.querySelector<HTMLFormElement>('#rsvp-form');
const submitButton = document.querySelector<HTMLButtonElement>('#submit-button');
const messageDiv = document.querySelector<HTMLElement>('#form-message');
const dietaryGroup = document.querySelector<HTMLElement>('#dietary-group');

if (form && submitButton && messageDiv && dietaryGroup) {
	const buttonText = submitButton.querySelector<HTMLElement>('.button-text');

	const showMessage = (type: 'success' | 'error', text: string) => {
		messageDiv.className = `form-message ${type}`;
		messageDiv.textContent = text;
		messageDiv.style.display = 'block';
	};

	const setButtonState = (disabled: boolean, text: string) => {
		submitButton.disabled = disabled;
		if (buttonText) {
			buttonText.textContent = text;
		}
	};

	form.addEventListener('change', (e) => {
		if (!(e.target instanceof HTMLInputElement) || e.target.name !== 'attending') {
			return;
		}
		dietaryGroup.style.display = e.target.value === 'yes' ? 'flex' : 'none';
	});

	form.addEventListener('submit', async (e) => {
		e.preventDefault();

		setButtonState(true, 'Sender...');
		messageDiv.style.display = 'none';

		const { error } = await actions.submitRSVP(new FormData(form));

		if (error) {
			console.error('RSVP form: Error submitting form:', error);
			showMessage('error', error.message ?? 'Noe gikk galt. Vennligst prøv igjen senere.');
		} else {
			showMessage('success', 'Takk! Vi har mottatt svaret ditt.');
			form.reset();
			dietaryGroup.style.display = 'none';
		}

		setButtonState(false, 'Send');
	});
}

