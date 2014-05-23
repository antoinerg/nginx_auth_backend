# config.ru (run with rackup)
require './app'

use Rack::FiberPool
use Rack::CommonLogger
run Auth