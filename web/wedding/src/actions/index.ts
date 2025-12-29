import { defineAction, ActionError } from 'astro:actions';
import { z } from 'astro/zod';
import { Resend } from 'resend';

const rsvpSchema = z.object({
	names: z.string().min(1, 'Navn er påkrevd'),
	attending: z.enum(['yes', 'no']),
	dietaryRestrictions: z.string().optional()
});

export const server = {
	submitRSVP: defineAction({
		accept: 'form',
		input: rsvpSchema,
		handler: async ({ names, attending, dietaryRestrictions }) => {
			if (!import.meta.env.RESEND_API_KEY) {
				throw new ActionError({
					code: 'BAD_REQUEST',
					message: 'Email-tjeneste ikke konfigurert'
				});
			}

			const resend = new Resend(import.meta.env.RESEND_API_KEY);
			const attendingText = attending === 'yes' ? 'Kommer' : 'Kommer dessverre ikke';

			try {
				const { error } = await resend.emails.send({
					from: 'Henrik & Ragnhild <onboarding@resend.dev>',
					to: import.meta.env.RECIPIENT_EMAIL,
					subject: `RSVP`,
					html: `
						<h2>Ny RSVP</h2>
						<p><strong>Navn:</strong> ${names}</p>
						<p><strong>Status:</strong> ${attendingText}</p>
						${dietaryRestrictions ? `<p><strong>Spesielle kosthold:</strong> ${dietaryRestrictions}</p>` : ''}
						<hr>
						<p><small>Sendt ${new Date().toLocaleString('no-NO')}</small></p>
					`
				});

				if (error) {
					console.error('Error sending RSVP email:', error);
					throw new ActionError({
						code: 'INTERNAL_SERVER_ERROR',
						message: 'Kunne ikke sende RSVP. Vennligst prøv igjen senere.'
					});
				}

				return {
					success: true
				};
			} catch (error) {
				console.error('Error sending RSVP email:', error);
				throw new ActionError({
					code: 'INTERNAL_SERVER_ERROR',
					message: 'Kunne ikke sende RSVP. Vennligst prøv igjen senere.'
				});
			}
		}
	})
};

