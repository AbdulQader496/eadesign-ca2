package com.example.ead.be;

import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.env.Environment;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.Arrays;
import java.util.List;

@RestController
public class ServiceController {

	@Autowired
	private Environment env;

	private Persistence p;

	//This method is needed because the application.properties is read AFTER all injections have happened.
	@PostConstruct
	private void postConstruct() {
		String databaseUrl = requireProperty("databaseUrl");
		String databaseName = requireProperty("databaseName");
		String databaseCollection = requireProperty("databaseCollection");

		System.out.println("******************************************************");
		System.out.println("******************************************************");
		System.out.println("******************************************************");
		System.out.println("env mongoUri:"+databaseUrl);
		System.out.println("env dbName:"+databaseName);
		System.out.println("env dbName:"+databaseCollection);
		System.out.println("******************************************************");
		System.out.println("******************************************************");
		System.out.println("******************************************************");

		 p = new Persistence(databaseUrl, databaseName, databaseCollection);
	}

	private String requireProperty(String key) {
		String value = env.getProperty(key);
		if (value == null || value.isBlank()) {
			throw new IllegalStateException("Missing required property: " + key);
		}
		return value;
	}

	@GetMapping("/")
	public String index() {
		return "Greetings from EAD CA2 Template project 2023-24!";
	}

	@GetMapping("/health")
	public String health() {
		return "OK";
	}

	@GetMapping("/recipes")
	public List<Recipe> getAllRecipes()
	{
		System.out.println("About to get all the recipes in MongoDB!");
		return p.getAllRecipes();
	}

	@DeleteMapping("/recipe/{name}")
	private int deleteRecipe(@PathVariable("name") String name)
	{
		System.out.println("About to delete all the recipes named "+name);
		return p.deleteRecipesByName(Arrays.asList(name));
	}

	@PostMapping("/recipe")
	@ResponseStatus(HttpStatus.CREATED)
	public int saveRecipe(@RequestBody Recipe rec)
	{
		System.out.println("About to add the following recipe: "+rec);
		return p.addRecipes(Arrays.asList(rec));
	}

}
