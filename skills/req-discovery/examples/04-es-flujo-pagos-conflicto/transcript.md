# Transcript — Flujo de pagos del checkout

[00:00:00] Sofía: Che, el otro tema que quedó pendiente de la reunión con el cliente es el flujo de pago. ¿Lucas, te sumaste bien o entrás ahora?

[00:00:08] Lucas: No, estoy, dale, contame.

[00:00:10] Sofía: Bueno, la idea que habíamos hablado el cliente y yo era que se pueda pagar como invitado, sin necesidad de crear cuenta antes. Menos fricción, el usuario entra, compra, listo.

[00:00:22] Martina: Sí, eso simplifica bastante el checkout técnicamente también, menos pasos, menos formularios.

[00:00:28] Sofía: Exacto, y el cliente estaba bastante convencido de eso, decía que en el checkout viejo perdían un montón de gente justo ahí, en el paso de crear cuenta.

[00:00:37] Lucas: Mmm, esperá, antes de que lo demos por cerrado — ¿esto es para todos los montos o hay algún tope?

[00:00:44] Sofía: No se habló de tope, sería para cualquier compra.

[00:00:48] Lucas: Ahí tengo un problema. Sin cuenta, sin verificación previa, quedamos muy expuestos a fraude con tarjeta robada, sobre todo en productos de ticket alto. Ya nos pasó en otro proyecto y fue un lío grande con las devoluciones al banco.

[00:01:02] Sofía: Uh, no había pensado eso.

[00:01:05] Lucas: Yo preferiría que pidamos registro antes de pagar, no algo pesado, pero al menos email y verificación, para tener algo de control anti-fraude antes de procesar la tarjeta.

[00:01:16] Martina: Eso agrega un paso más al flujo igual, ¿no? Justo lo que querían sacar.

[00:01:21] Lucas: Sí, agrega un paso, pero comparado con perder guita en contracargos, para mí vale la pena.

[00:01:28] Sofía: No, tenés razón, no había pensado el ángulo de fraude. Mejor pidamos el registro antes de pagar entonces, dejamos de lado lo de invitado por ahora.

[00:01:38] Martina: Ok, dale, entonces el checkout va a requerir cuenta creada antes del paso de pago, no invitado.

[00:01:44] Sofía: Sí, eso. Se lo explico así al cliente, con el motivo del fraude, seguro lo entienden.

[00:01:50] Lucas: Buenísimo. Ah, aparte de esto — ¿vamos a mergear esa branch del formulario de registro antes de arrancar con esto, o la dejamos como está?

[00:01:58] Martina: Sí, dale, la mergeo esta semana, así arrancamos sobre eso limpio.

[00:02:03] Sofía: Perfecto, gracias.
