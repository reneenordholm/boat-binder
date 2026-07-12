class ApplicationExceptions
  def self.call(env)
    error_env = env.dup
    error_env["REQUEST_METHOD"] = "GET"

    Rails.application.routes.call(error_env)
  end
end
