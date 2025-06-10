const port = 8080
const express = require('express')
const app = express()
const startup_time = new Date().toISOString()

app.get('/', (req, res) => {
	res.send(`<!DOCTYPE html>
		<html>
		<body>
			<h1>Hello Big Data</h1>
			<p>Startup time: ${startup_time}</p>
			<p>Current time: ${new Date().toISOString()}</p>
		</body>
		</html>
	`);
})

app.listen(port, () => console.log(`Listening on port ${port}`))
