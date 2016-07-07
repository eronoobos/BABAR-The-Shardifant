
FactoryBuildersHandler = class(Module)

function FactoryBuildersHandler:Name()
	return "FactoryBuildersHandler"
end

function FactoryBuildersHandler:internalName()
	return "factorybuildershandler"
end 

function FactoryBuildersHandler:Init()
	self.DebugEnabled = true
	self:UpdateFactories()
	self:EchoDebug('Initialize')
end


