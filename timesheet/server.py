import aiopg
import asyncio
from aiohttp import web

loop = asyncio.get_event_loop()
app = web.Application(loop=loop)


async def get_today():
    conn = await aiopg.connect(database='timesheet',
                               host='127.0.0.1')
    cur = await conn.cursor()
    await cur.execute("SELECT * FROM timesheet.today")
    retval = []
    async for elem in cur:
        return elem

async def index(request):
    values = await get_today()
    for value in values:
        print("..",values)
    return web.Response(text="Hello there")


app.router.add_get("/", index)
web.run_app(app, host='127.0.0.1', port=8088)
