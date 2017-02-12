import sys
from jinja2 import Environment, PackageLoader, select_autoescape
env = Environment(loader=PackageLoader('timesheet', 'templates'))

schema_name = sys.argv[1]
schema = env.get_template("schema.sql")
print(schema.render(schema_name=schema_name))
