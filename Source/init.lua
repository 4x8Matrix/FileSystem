local Promise = require(script.Packages.promise)

local FileSystem = { }

FileSystem.Interface = { }
FileSystem.Interface.Context = { }

function FileSystem.Interface.Context:setVaradicParameters(...)
	self._varadicParameters = { ... }
end

function FileSystem.Interface.Context:addInitlifecycleMethod(methodName)
	table.insert(self._initLifecycleMethods, methodName)
end

function FileSystem.Interface.Context:addStartlifecycleMethod(methodName)
	table.insert(self._startLifecycleMethods, methodName)
end

function FileSystem.Interface.Context.new()
	return setmetatable({
		_initLifecycleMethods = {},
		_startLifecycleMethods = {},
		_varadicParameters = {}
	}, { __index = FileSystem.Interface.Context })
end

function FileSystem.Interface:importModule(module: ModuleScript, context: typeof(FileSystem.Interface.Context))
	if not module:IsA("ModuleScript") then
		return
	end

	return Promise.new(function(resolve)
		local moduleResource = require(module)

		if context then
			for _, lifecycleMethod in context._initLifecycleMethods do
				if not moduleResource[lifecycleMethod] then
					continue
				end

				moduleResource[lifecycleMethod](moduleResource, table.unpack(context._varadicParameters))
			end
		end

		resolve(moduleResource)
	end)
end

function FileSystem.Interface:importModulesFromTable(moduleArray: { ModuleScript }, context: typeof(FileSystem.Interface.Context))
	local importPromises = { }

	for _, moduleInstance in moduleArray do
		if not moduleInstance:IsA("ModuleScript") then
			continue
		end

		table.insert(importPromises, self:importModule(moduleInstance, context))
	end

	return Promise.allSettled(importPromises):andThen(function(promiseStatus)
		local trackedModules = { }

		for promiseIndex in promiseStatus do
			local moduleResource = importPromises[promiseIndex]._values[1]

			if not moduleResource then
				continue
			end

			table.insert(trackedModules, moduleResource)

			if not context then
				continue
			end

			for _, lifecycleMethod in context._startLifecycleMethods do
				if not moduleResource[lifecycleMethod] then
					continue
				end

				moduleResource[lifecycleMethod](moduleResource, table.unpack(context._varadicParameters))
			end
		end

		return trackedModules
	end)
end

function FileSystem.Interface:importChildren(instance: Instance, context: typeof(FileSystem.Interface.Context))
	return self:importModulesFromTable(instance:GetChildren(), context)
end

function FileSystem.Interface:importDescendants(instance: Instance, context: typeof(FileSystem.Interface.Context))
	return self:importModulesFromTable(instance:GetDescendants(), context)
end

return FileSystem.Interface :: typeof(FileSystem.Interface)