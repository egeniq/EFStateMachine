Pod::Spec.new do |s|
  s.name         = "EFStateMachine"
  s.version      = "0.1.0"
  s.summary      = "A Simple State Machine in Swift."
  s.description  = <<-DESC
  This state machine is typically setup with an enum for its possible states, and an enum for its actions. The state
  of the machine determines wether an action is allowed to run. The state of a machine can only be changed via an
  action. The action handler returns the new state of the machine.

  It is also possible to register multiple handlers that get run when certain state changes occur.
                   DESC
  s.homepage     = "https://github.com/Egeniq/EFStateMachine"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Johan Kool" => "johan@koolistov.net" }
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.9"
  s.source       = { :git => "https://github.com/Egeniq/EFStateMachine.git", :tag => "v#{s.version}" }
  s.source_files = "StateMachine/*.swift"
  s.requires_arc = true
end
